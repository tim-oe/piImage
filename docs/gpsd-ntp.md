# GPS-Based NTP Server Configuration Guide

Complete guide for setting up a Stratum 1 NTP server using GPS with PPS (Pulse Per Second) on Raspberry Pi.

## Table of Contents

- [Hardware Requirements](#hardware-requirements)
- [Initial Setup](#initial-setup)
- [GPSD Configuration](#gpsd-configuration)
- [NTP Configuration](#ntp-configuration)
- [Verification and Testing](#verification-and-testing)
- [Troubleshooting](#troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Hardware-Specific Notes](#hardware-specific-notes)

---

## Hardware Requirements

### Recommended Hardware

**Best Options:**
- **Raspberry Pi 4 (2GB+)**: Best performance, stable serial timing
- **Raspberry Pi Zero 2 W**: Lowest power consumption (~1-1.5W), good serial timing
- **Waveshare MAX-M8Q GNSS HAT**: Purpose-built for Pi Zero, includes PPS

**Works But Has Limitations:**
- **Raspberry Pi 3 B+**: Higher power (~2.5W), serial timing jitter issues
- **Adafruit Ultimate GPS HAT**: Good quality but not optimized for Pi Zero form factor

### Key Features Needed
- GPS module with PPS (Pulse Per Second) output
- UART connection for NMEA data
- GPIO connection for PPS signal
- Clear view of sky for GPS signal

---

## Initial Setup

### 1. Enable UART and PPS

Edit `/boot/config.txt`:
```bash
sudo nano /boot/config.txt
```

Add or verify these lines:
```ini
# Enable hardware UART
enable_uart=1

# For Pi 3 B+: Swap Bluetooth to mini UART to give GPS the good UART
dtoverlay=miniuart-bt

# For Pi 4/Zero 2 W: Bluetooth doesn't interfere, but disable if not needed
# dtoverlay=disable-bt

# Enable PPS on GPIO (verify GPIO pin for your GPS HAT)
# Common pins: GPIO4, GPIO18
dtoverlay=pps-gpio,gpiopin=4

# Optional: Fix CPU frequency for better timing stability
force_turbo=1
# OR use performance governor (see below)
```

### 2. Configure Serial Console

Check if serial console is enabled:
```bash
cat /boot/cmdline.txt | grep console
```

**Important:** The serial console should NOT be on the same port as GPS. If you see `console=serial0` or `console=ttyAMA0`, you need to remove it.

Edit if needed:
```bash
sudo nano /boot/cmdline.txt
```

Remove any `console=serial0,115200` or `console=ttyAMA0,115200` entries.

### 3. Set CPU Governor for Stable Timing

Create a script to set performance mode on boot:
```bash
sudo nano /etc/rc.local
```

Add before `exit 0`:
```bash
# Set CPU to performance mode for stable GPS timing
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor
```

### 4. Create udev Rules

Create `/etc/udev/rules.d/100-gps.rules`:
```bash
sudo nano /etc/udev/rules.d/100-gps.rules
```

Add:
```bash
# Create symlink for GPS serial device
ACTION=="add", SUBSYSTEM=="tty", KERNEL=="ttyAMA0", SYMLINK+="gps0", GROUP="dialout", MODE="0660"

# Create symlink for PPS device
ACTION=="add", SUBSYSTEM=="pps", KERNEL=="pps0", SYMLINK+="gpspps0", GROUP="dialout", MODE="0660"
```

### 5. Reboot
```bash
sudo reboot
```

---

## GPSD Configuration

### 1. Install GPSD
```bash
sudo apt-get update
sudo apt-get install gpsd gpsd-clients pps-tools
```

### 2. Configure GPSD

Edit `/etc/default/gpsd`:
```bash
sudo nano /etc/default/gpsd
```

Configuration:
```bash
# Devices gpsd should collect from at boot time
# Use symlink (cleaner) or actual device path
DEVICES="/dev/gps0 /dev/pps0"
# Alternative: DEVICES="/dev/ttyAMA0 /dev/pps0"

# GPSD options
# -n : Start immediately, don't wait for client
# -b : Don't change device speed (prevents baud rate issues)
# -G : Listen on all interfaces (optional, helps with some timing issues)
GPSD_OPTIONS="-n -b -G"

# Disable USB auto-detection (not needed for GPIO GPS)
USBAUTO="false"

# Socket location
GPSD_SOCKET="/var/run/gpsd.sock"
```

### 3. Start GPSD
```bash
sudo systemctl enable gpsd
sudo systemctl start gpsd
```

### 4. Verify GPSD is Working

Wait 2-3 minutes for GPS to acquire satellites, then:
```bash
# Check GPS status
cgps -s

# Detailed monitoring
gpsmon

# Check PPS
sudo ppstest /dev/pps0
```

**What to look for:**

**cgps output:**
- Status should be "3D FIX"
- 8+ satellites visible
- Time should be accurate

**gpsmon output:**
- `TOFF`: Time offset, typically 0.1-0.5 seconds (this is normal)
- `PPS`: Should show ~0.001-0.005 seconds (1-5ms)

**ppstest output:**
```
source 0 - assert 1768967348.998193988, sequence: 293
source 0 - assert 1768967349.998191259, sequence: 294
```
- Should increment by exactly 1 second
- Nanosecond portion should be very stable (±50µs drift is excellent)

---

## NTP Configuration

### 1. Install NTP
```bash
sudo apt-get install ntp
```

### 2. Basic NTP Configuration

Edit `/etc/ntp.conf`:
```bash
sudo nano /etc/ntp.conf
```

**Complete working configuration:**
```conf
# Drift file to store frequency offset
driftfile /var/lib/ntp/ntp.drift

# Logs
logfile /var/log/ntp.log
statsdir /var/log/ntpstats/
statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# Leap seconds file
leapfile /usr/share/zoneinfo/leap-seconds.list

# Internet time servers (fallback and for initial sync)
pool pool.ntp.org iburst

# _GPS_SERIAL_SHM_DRIVER_
# GPS serial data via shared memory - provides coarse second reference
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.315 stratum 3
# _GPS_SERIAL_SHM_DRIVER_

# _GPS_PPS_SHM_DRIVER_
# GPS PPS via shared memory - provides microsecond precision
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1
# _GPS_PPS_SHM_DRIVER_

# _KERNEL_PPS_DRIVER_ (optional backup)
# Direct kernel PPS - usually redundant with SHM(2) but can be kept as backup
server 127.127.22.0 minpoll 4 maxpoll 4
fudge 127.127.22.0 refid PPSH flag3 1
# _KERNEL_PPS_DRIVER_

# Access control
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1

# Allow local network to query (adjust subnet as needed)
# restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap
```

### 3. Understanding the Configuration

**SHM Driver Numbers:**
- `127.127.28.0` = SHM(0) = GPS serial NMEA data
- `127.127.28.1` = SHM(1) = Usually unused or alternative GPS source
- `127.127.28.2` = SHM(2) = GPS PPS data (when gpsd provides it)

**Kernel PPS Driver:**
- `127.127.22.0` = Direct kernel PPS via `/dev/pps0`

**Fudge Parameters:**
- `time1`: Time offset compensation in seconds (adjust based on your readings)
- `refid`: Reference ID string (shown in ntpq output)
- `stratum`: Server stratum level (lower = more authoritative)
- `flag1`: Enable PPS discipline
- `flag3`: Enable kernel PPS
- `prefer`: Marks this source as preferred when multiple sources available

**Poll Intervals:**
- `minpoll 4` = 2^4 = 16 seconds minimum
- `maxpoll 4` = 2^4 = 16 seconds maximum
- For GPS/PPS, keep polling fast and consistent

### 4. Start NTP
```bash
sudo systemctl enable ntp
sudo systemctl restart ntp
```

### 5. Wait for Convergence

NTP needs 15-30 minutes to stabilize. During this time:
- It's evaluating all time sources
- Building statistics on reliability
- Adjusting clock discipline

**Do not restart NTP repeatedly** - let it run for at least 30 minutes.

---

## Verification and Testing

### Monitor NTP Status

**Basic peer status:**
```bash
ntpq -pnu
```

**Example of good output:**
```
     remote           refid      st t when poll reach   delay   offset   jitter
===============================================================================
+99.28.14.242    ....             1 u   30   64  377 42.669ms 5.1461ms 2.5703ms
+SHM(0)          .GPS.            3 l   14   16  377      0ns -1.104ms 6.1270ms
*SHM(2)          .PPS.            0 l   12   16  377      0ns 579.39us 101.97us
oPPS(0)          .PPSH.           0 l   12   16  377      0ns 579.39us 190.30us
```

**Symbol meanings:**
- `*` = System peer (currently syncing to this source)
- `+` = Good peer, could be used
- `o` = PPS peer (provides timing but needs coarse reference)
- `-` = Outlier, not currently used
- `x` = Falseticker, rejected as unreliable
- ` ` = Discarded or not yet evaluated

**Column meanings:**
- `st` = Stratum (0 = GPS/atomic, 1 = synced to stratum 0, etc.)
- `when` = Seconds since last poll
- `poll` = Polling interval in seconds
- `reach` = Octal bitmask of last 8 polls (377 = 11111111 = all successful)
- `offset` = Time difference from this source
- `jitter` = Variation in offset measurements

### Detailed Status
```bash
# System status
ntpq -c sysinfo

# All variables
ntpq -c rv

# Peer details
ntpq -c associations
ntpq -c peers -n

# Kernel discipline info (when using kernel PPS)
ntpq -c kerninfo
```

### Monitor Shared Memory
```bash
# Watch real-time SHM updates
ntpshmmon
```

**Example output:**
```
#      Name  Seen@                 Clock                 Real                 L Prc
sample NTP0  1768968974.834395489  1768968974.314610003  1768968974.000000000 0 -20
sample NTP2  1768968974.834461790  1768968973.999437925  1768968974.000000000 0 -20
```

**Understanding the columns:**
- `Name`: NTP0 = SHM(0), NTP2 = SHM(2)
- `Seen@`: When sample was received (system time)
- `Clock`: GPS time as reported
- `Real`: Reference second boundary
- `L`: Leap second indicator
- `Prc`: Precision (negative log2 of precision in seconds)

**Calculate offset:**
- Clock - Real = actual offset
- For PPS: `999437925 ns - 000000000 ns = -562 µs` (562µs before the second)

### Check PPS Hardware
```bash
# Verify PPS device exists
ls -l /dev/pps0

# Check kernel PPS
sudo ppstest /dev/pps0

# Check dmesg for PPS registration
dmesg | grep pps
```

Expected dmesg output:
```
[    3.456789] pps_core: LinuxPPS API ver. 1 registered
[    3.456792] pps_core: Software ver. 5.3.6 - Copyright 2005-2007 Rodolfo Giometti
[    4.123456] pps pps0: new PPS source pps-gpio.0
[    4.123467] pps pps0: Registered IRQ 123 as PPS source
```

### Check System Logs
```bash
# NTP logs
sudo tail -f /var/log/ntp.log
sudo tail -f /var/log/syslog | grep ntp

# GPSD logs
journalctl -u gpsd -f
```

---

## Troubleshooting

### Problem: GPS Not Getting Fix

**Symptoms:**
- `cgps` shows "NO FIX" or "2D FIX"
- Few satellites visible

**Solutions:**

1. **Check antenna placement:**
   - Needs clear view of sky
   - Away from metal objects
   - Not indoors if using passive antenna
   - Consider external active antenna

2. **Wait longer:**
   - Cold start can take 5-15 minutes
   - Warm start: 30-60 seconds

3. **Check GPS module:**
```bash
   # See raw NMEA data
   cat /dev/gps0
   # Should show $GP... sentences scrolling
   
   # Detailed status
   gpsmon
```

4. **Verify serial connection:**
```bash
   # Check device exists
   ls -l /dev/gps0 /dev/ttyAMA0
   
   # Check it's not in use
   sudo lsof | grep ttyAMA0
```

### Problem: PPS Not Working

**Symptoms:**
- `ppstest` shows no output or errors
- `ntpq -pnu` shows PPS with `x` or not appearing

**Solutions:**

1. **Verify PPS kernel module loaded:**
```bash
   lsmod | grep pps
   dmesg | grep pps
```

2. **Check PPS device permissions:**
```bash
   ls -l /dev/pps0
   # Should show: crw-rw---- 1 root dialout
   
   # Add user to dialout group if needed
   sudo usermod -a -G dialout $USER
```

3. **Test PPS directly:**
```bash
   sudo ppstest /dev/pps0
```
   Should show pulses every second with stable nanosecond timestamps.

4. **Check GPIO configuration:**
```bash
   cat /boot/config.txt | grep pps
   # Should show: dtoverlay=pps-gpio,gpiopin=4
```

5. **Verify correct GPIO pin:**
   - Check your GPS HAT documentation
   - Common pins: GPIO4, GPIO18
   - Adafruit GPS HAT: GPIO4
   - Waveshare HATs: Check specific model docs

### Problem: NTP Shows GPS/PPS as Falseticker (x)

**Symptoms:**
- `ntpq -pnu` shows `x` next to GPS or PPS sources
- Large offset or jitter

**Causes & Solutions:**

1. **GPS time offset too large:**
   
   Check actual offset:
```bash
   ntpshmmon
```
   
   Adjust `time1` fudge factor in `/etc/ntp.conf`:
```conf
   # If GPS shows +50ms offset, add 0.050 to time1
   # If GPS shows -50ms offset, subtract 0.050 from time1
   fudge 127.127.28.0 refid GPS time1 0.315
```

2. **GPS jitter too high:**
   
   Check in `ntpq -pnu` - jitter should be <50ms for GPS serial.
   
   If jitter is >50ms:
   - On Pi 3 B+: This is a known hardware limitation
   - Solution: Use SHM(2) for PPS instead of relying on SHM(0)
   - Or upgrade to Pi 4 / Pi Zero 2 W

3. **PPS and GPS disagree on second boundary:**
   
   The PPS needs GPS serial to know which second the pulse belongs to.
   
   Check both sources:
```bash
   ntpshmmon
```
   
   If GPS serial (NTP0) is stable, but PPS (NTP2) is marked as falseticker:
   - Increase stratum of GPS serial to make it lower priority
   - Ensure `prefer` flag is on PPS source

4. **System time too far off:**
   
   If system time is >1000 seconds wrong, NTP won't sync.
   
   Solution:
```bash
   # Stop NTP
   sudo systemctl stop ntp
   
   # Set time manually (roughly correct)
   sudo date -s "2026-01-21 12:00:00"
   
   # Or sync from internet once
   sudo ntpd -gq
   
   # Start NTP
   sudo systemctl start ntp
```

### Problem: High GPS Serial Jitter (±50-100ms)

**Symptoms:**
- `ntpq -pnu` shows SHM(0) with 50-100ms jitter
- `ntpshmmon` shows TOFF varying widely (e.g., 0.32 to 0.42 seconds)
- `gpsmon` TOFF value unstable

**This is NORMAL on Raspberry Pi 3 B+ due to hardware limitations.**

**Solutions:**

1. **Use SHM(2) for PPS (Recommended):**
   
   GPSD provides PPS data via SHM(2) which bypasses serial timing issues:
```conf
   server 127.127.28.2 minpoll 4 maxpoll 4 prefer
   fudge 127.127.28.2 refid PPS flag1 1
```

2. **Demote GPS serial to low priority:**
```conf
   server 127.127.28.0 minpoll 4 maxpoll 4
   fudge 127.127.28.0 refid GPS time1 0.350 stratum 5
```

3. **Upgrade hardware:**
   - Pi 4: Better UART, less jitter (~5-10ms typical)
   - Pi Zero 2 W: Good UART, low power, better than Pi 3 B+

4. **Disable CPU frequency scaling:**
```bash
   # Add to /boot/config.txt
   force_turbo=1
```

5. **Check for interfering processes:**
```bash
   top -bn1 | head -20
```
   Look for processes using significant CPU, especially:
   - `w1_bus_master` (1-Wire temperature sensors)
   - Heavy background tasks
   
   Disable if not needed:
```bash
   # Disable 1-Wire in /boot/config.txt
   # Comment out: dtoverlay=w1-gpio
```

### Problem: PPS Won't Become System Peer (stays as 'o')

**Symptoms:**
- PPS shows `o` instead of `*` in `ntpq -pnu`
- Internet servers are preferred over GPS

**Causes & Solutions:**

1. **GPS serial too unstable:**
   
   PPS needs a stable coarse reference. If GPS serial (SHM(0)) has high jitter, PPS won't trust it.
   
   Solution: Use SHM(2) for PPS which is more stable:
```conf
   server 127.127.28.2 minpoll 4 maxpoll 4 prefer
   fudge 127.127.28.2 refid PPS flag1 1
```

2. **Not enough time passed:**
   
   NTP needs 20-30 minutes to evaluate sources and switch to PPS.
   
   Solution: Wait longer, check again.

3. **Missing `prefer` flag:**
   
   Without `prefer`, NTP may choose internet servers even when PPS is available.
   
   Solution:
```conf
   server 127.127.28.2 minpoll 4 maxpoll 4 prefer
```

4. **Internet servers have better metrics:**
   
   If internet latency is very low and stable, NTP might prefer them.
   
   Solution: Either accept this (you still have PPS discipline), or:
```conf
   # Remove internet servers for fully autonomous operation
   # pool pool.ntp.org iburst
```

### Problem: "Device or resource busy" When Accessing GPS

**Symptoms:**
```bash
cat /dev/gps0
# cat: /dev/gps0: Device or resource busy
```

**Cause:**
GPSD has the device open exclusively.

**This is NORMAL** - GPSD needs exclusive access to read GPS data.

**Solutions:**

1. **Use gpsd clients instead:**
```bash
   cgps -s        # GPS status
   gpsmon         # Detailed monitoring
   gpspipe -r     # Raw NMEA data
```

2. **Temporarily stop gpsd to test:**
```bash
   sudo systemctl stop gpsd
   cat /dev/gps0  # Should show NMEA sentences
   sudo systemctl start gpsd
```

### Problem: NTP Not Starting or Crashing

**Check status:**
```bash
sudo systemctl status ntp
journalctl -u ntp -n 50
```

**Common issues:**

1. **Configuration syntax error:**
```bash
   # Test configuration
   sudo ntpd -n -d -g
   # Watch for error messages
```

2. **Port 123 already in use:**
```bash
   sudo netstat -tulpn | grep 123
   # Kill competing process or remove conflicting packages
```

3. **Conflicting time services:**
```bash
   # Check what's installed
   dpkg -l | grep -E "ntp|chrony|systemd-timesyncd"
   
   # Disable conflicting services
   sudo systemctl stop systemd-timesyncd
   sudo systemctl disable systemd-timesyncd
```

### Problem: Time Drifting Despite GPS Lock

**Check drift:**
```bash
ntpq -c rv | grep offset
cat /var/lib/ntp/ntp.drift
```

**Possible causes:**

1. **Hardware clock quality:**
   
   Raspberry Pi's RTC (if present) or system clock may have significant drift.
   
   Solution: This is why GPS discipline is important - it continuously corrects drift.

2. **Temperature effects:**
   
   Clock frequency changes with temperature.
   
   Solution: Ensure good ventilation, consider enclosure with temperature stability.

3. **NTP not converged:**
   
   Check `ntpq -c rv | grep stratum` - should be 1 when locked to GPS.
   
   Wait for convergence (can take 1-2 hours for full stabilization).

### Problem: Lost NTP Configuration After Update

**Some system updates may overwrite `/etc/ntp.conf`.**

**Prevention:**
```bash
# Backup your config
sudo cp /etc/ntp.conf /etc/ntp.conf.backup

# After updates, compare:
diff /etc/ntp.conf /etc/ntp.conf.backup

# Restore if needed:
sudo cp /etc/ntp.conf.backup /etc/ntp.conf
sudo systemctl restart ntp
```

---

## Performance Optimization

### Fine-Tuning time1 Offset

The `time1` parameter compensates for GPS serial latency. Fine-tune it for best accuracy:

1. **Initial setup** - use approximate value:
```bash
   # Check gpsmon TOFF value
   gpsmon
   # If TOFF shows ~0.320, use time1 0.320
```

2. **After NTP stabilizes** (30+ minutes), check actual offset:
```bash
   ntpq -pnu
```
   Look at the offset column for SHM(0).

3. **Adjust time1:**
   - If offset is **positive** (+10ms), **increase** time1 by 0.010
   - If offset is **negative** (-10ms), **decrease** time1 by 0.010

4. **Restart and wait:**
```bash
   sudo systemctl restart ntp
```
   Wait 30 minutes, check again, repeat until offset is near zero.

### Optimal Configuration for Different Hardware

**Raspberry Pi 4:**
```conf
# GPS Serial - very stable on Pi 4
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.135 stratum 1

# PPS via SHM
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1

# Kernel PPS (optional)
server 127.127.22.0 minpoll 4 maxpoll 4
fudge 127.127.22.0 refid KPPS flag3 1
```

**Raspberry Pi Zero 2 W:**
```conf
# Similar to Pi 4, good serial stability
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.140 stratum 1

# PPS via SHM
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1
```

**Raspberry Pi 3 B+:**
```conf
# GPS Serial - high jitter, demote
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.350 stratum 3

# PPS via SHM - preferred source
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1

# Keep internet servers as backup for coarse time
pool pool.ntp.org iburst
```

### Expected Performance Metrics

**Excellent Performance:**
- Offset: <500µs
- Jitter: <100µs
- Stratum: 1 (when synced to GPS)
- Reach: 377 (all polls successful)

**Good Performance:**
- Offset: <2ms
- Jitter: <500µs
- Stratum: 1
- Reach: 377

**Acceptable (Pi 3 B+ limitation):**
- Offset: <5ms
- Jitter: <5ms
- Stratum: 1
- Some PPS sources may show `o` instead of `*`

### Monitoring and Logging

**Create monitoring script** `/usr/local/bin/ntp-monitor.sh`:
```bash
#!/bin/bash

LOG_FILE="/var/log/ntp-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "=== $DATE ===" >> $LOG_FILE
ntpq -pnu >> $LOG_FILE
echo "" >> $LOG_FILE

# Alert if not synced to PPS
if ! ntpq -pnu | grep -q '^\*.*PPS'; then
    echo "WARNING: Not synced to PPS!" >> $LOG_FILE
fi

# Alert if GPS has no fix
if ! cgps -s | grep -q '3D FIX'; then
    echo "WARNING: GPS has no 3D fix!" >> $LOG_FILE
fi
```

Make executable and add to cron:
```bash
sudo chmod +x /usr/local/bin/ntp-monitor.sh

# Add to crontab (every hour)
sudo crontab -e
# Add line:
0 * * * * /usr/local/bin/ntp-monitor.sh
```

### Network Configuration for NTP Server

If serving time to other devices on your network:

1. **Configure firewall:**
```bash
   sudo ufw allow 123/udp
```

2. **Update /etc/ntp.conf access control:**
```conf
   # Allow queries from local network
   restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap
```

3. **Configure clients:**
   On other devices, set NTP server to your Pi's IP:
```conf
   server 192.168.1.100 iburst prefer
```

---

## Hardware-Specific Notes

### Adafruit Ultimate GPS HAT (Product ID: 2324)

**GPIO Connections:**
- Serial: `/dev/ttyAMA0` (RX on GPIO15, TX on GPIO14)
- PPS: GPIO4 (pin 7)

**Configuration:**
```ini
# /boot/config.txt
enable_uart=1
dtoverlay=miniuart-bt
dtoverlay=pps-gpio,gpiopin=4
```

**Known Issues:**
- Pi 3 B+: Serial timing jitter due to hardware limitations
- Solution: Use SHM(2) for PPS, demote SHM(0)

### Waveshare MAX-M8Q GNSS HAT

**GPIO Connections:**
- Serial: `/dev/ttyAMA0`
- PPS: GPIO18 (verify in product documentation)

**Configuration:**
```ini
# /boot/config.txt
enable_uart=1
dtoverlay=pps-gpio,gpiopin=18  # Verify GPIO pin
```

**Features:**
- Designed for Pi Zero form factor
- Low power consumption
- Built-in patch antenna + external antenna option

### Raspberry Pi 3 B+ Specific Issues

**Serial Port Limitations:**
- Bluetooth shares resources with hardware UART
- Mini UART has frequency-dependent timing
- Results in 50-100ms GPS serial jitter

**Mitigations:**
```ini
# /boot/config.txt
dtoverlay=miniuart-bt  # Gives GPS the good UART
force_turbo=1          # Fixes CPU frequency
```

**Best Practice:**
- Use SHM(2) for PPS (bypasses serial timing issues)
- Accept that GPS serial will have high jitter
- Consider upgrade to Pi 4 or Pi Zero 2 W for better performance

### Power Consumption Comparison

| Hardware | Idle Power | With GPS | Annual Cost* |
|----------|-----------|----------|--------------|
| Pi 3 B+ | ~2.5W | ~3.0W | ~$3.15 |
| Pi 4 2GB | ~3.5W | ~4.0W | ~$4.20 |
| Pi Zero 2 W | ~1.2W | ~1.5W | ~$1.57 |

*Based on $0.12/kWh, 24/7 operation

**For solar/battery systems:** Pi Zero 2 W is strongly recommended.

---

## Common NTP Configuration Patterns

### Pattern 1: Autonomous GPS-Only (No Internet)

**Use case:** Fully offline, GPS-disciplined time server
```conf
driftfile /var/lib/ntp/ntp.drift

# GPS Serial (coarse reference)
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.315 stratum 1
GPS PPS (precision)
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1
Kernel PPS backup
server 127.127.22.0 minpoll 4 maxpoll 4
fudge 127.127.22.0 refid KPPS flag3 1
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
Allow local network
restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap

**Pros:**
- Completely autonomous
- No internet dependency
- True Stratum 1 server

**Cons:**
- Takes longer to acquire initial time (cold start)
- No fallback if GPS fails

### Pattern 2: Hybrid (GPS Primary, Internet Fallback)

**Use case:** Best accuracy with GPS, internet backup
```conf
driftfile /var/lib/ntp/ntp.drift

# Internet servers (fallback, initial sync)
pool pool.ntp.org iburst

# GPS Serial
server 127.127.28.0 minpoll 4 maxpoll 4
fudge 127.127.28.0 refid GPS time1 0.315 stratum 1

# GPS PPS (preferred)
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1

# Kernel PPS
server 127.127.22.0 minpoll 4 maxpoll 4
fudge 127.127.22.0 refid KPPS flag3 1

restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
```

**Pros:**
- Fast initial sync via internet
- Microsecond accuracy via GPS PPS
- Automatic failover if GPS fails

**Cons:**
- Requires internet connection
- Not truly autonomous

### Pattern 3: Internet + PPS Only (No GPS Serial)

**Use case:** Work around unstable GPS serial on Pi 3 B+
```conf
driftfile /var/lib/ntp/ntp.drift

# Internet for coarse time
pool pool.ntp.org iburst

# GPS PPS for precision discipline
server 127.127.28.2 minpoll 4 maxpoll 4 prefer
fudge 127.127.28.2 refid PPS flag1 1

restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
```

**Pros:**
- Avoids GPS serial jitter issues
- Still achieves microsecond accuracy
- Simpler configuration

**Cons:**
- Requires internet for second boundary
- Not autonomous

---

## Quick Reference Commands

### Daily Operations
```bash
# Check NTP status
ntpq -pnu

# Detailed peer info
ntpq -p

# System variables
ntpq -c rv

# Check GPS
cgps -s
gpsmon

# Monitor shared memory
ntpshmmon

# Check PPS
sudo ppstest /dev/pps0

# Restart services
sudo systemctl restart gpsd
sudo systemctl restart ntp

# View logs
sudo tail -f /var/log/ntp.log
journalctl -u ntp -f
journalctl -u gpsd -f
```

### Diagnostic Commands
```bash
# Check devices
ls -l /dev/gps* /dev/pps*

# Check GPS serial
sudo cat /dev/ttyAMA0  # Raw output (stop gpsd first)
gpspipe -r             # Via gpsd

# Check kernel messages
dmesg | grep -E "ttyAMA|pps|gps"

# Check process
ps aux | grep -E "ntpd|gpsd"

# Check ports
sudo netstat -tulpn | grep 123

# Check shared memory
ipcs -m

# System info
uname -a
cat /etc/os-release
gpsd -V
ntpd --version
```

---

## Additional Resources

**Official Documentation:**
- GPSD: https://gpsd.gitlab.io/gpsd/
- NTP: https://www.ntp.org/documentation/
- Raspberry Pi: https://www.raspberrypi.org/documentation/

**Useful Tools:**
- NTP Pool Project: https://www.ntppool.org/
- GPS Time Server HOWTO: http://www.catb.org/gpsd/gpsd-time-service-howto.html

**Community Support:**
- Raspberry Pi Forums: https://forums.raspberrypi.com/
- GPSD Mailing List: https://lists.nongnu.org/mailman/listinfo/gpsd-users

---

## Appendix: Understanding NTP and GPS Time

### How GPS Time Works

**GPS Satellites:**
- Each satellite has atomic clocks
- Broadcast precise time signals
- Achieve ~10 nanosecond accuracy in space

**GPS Receiver:**
- Receives signals from 4+ satellites
- Calculates position and precise time
- Outputs NMEA sentences (serial data) and PPS pulse

**NMEA Serial Data:**
- Text messages with time, position, satellite info
- Transmitted via UART (serial port)
- Latency: 100-500ms (variable, depends on hardware)
- Used for "coarse" time - knowing which second

**PPS (Pulse Per Second):**
- GPIO pin goes high/low exactly once per second
- Aligned to GPS second boundary
- Accuracy: <1 microsecond
- Used for "precision" time - exact microsecond

### How NTP Discipline Works

**Clock Discipline:**
1. NTP compares system clock to reference sources
2. Calculates offset (how far off you are)
3. Gradually adjusts system clock frequency
4. Goal: Minimize offset and keep stable

**Why Gradual?**
- Sudden time jumps break applications
- Frequency adjustment is smoother
- Allows filtering of noise and outliers

**Convergence:**
- Initial sync: Minutes to hours
- Full discipline: 1-2 hours
- Continuous refinement thereafter

**PPS Discipline:**
- Requires knowing which second the PPS belongs to (via GPS serial or internet)
- Uses PPS edge to discipline microsecond timing
- Achieves <500µs offset when working properly

### Time Stratum Levels

- **Stratum 0:** Atomic clocks, GPS satellites (not directly accessible)
- **Stratum 1:** Directly synced to Stratum 0 (GPS receivers, atomic clocks)
- **Stratum 2:** Synced to Stratum 1 servers
- **Stratum 3:** Synced to Stratum 2 servers
- ... up to Stratum 15

**Your GPS NTP server is Stratum 1** when properly configured!

---

## Document Version

**Version:** 1.0  
**Last Updated:** January 21, 2026  
**Author:** Technical documentation based on real-world GPS/NTP configuration troubleshooting

**Changelog:**
- v1.0 (2026-01-21): Initial comprehensive guide covering GPSD/NTP configuration, troubleshooting, and hardware-specific notes for Raspberry Pi platforms