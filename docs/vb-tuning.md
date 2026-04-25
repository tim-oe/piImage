# Ubuntu 26.04 Guest on VirtualBox: Ultimate Performance Tuning Guide
**Host OS:** Ubuntu 24.04 LTS  
**Guest OS:** Ubuntu 26.04 LTS ("Resolute Raccoon")  
**Hypervisor:** VirtualBox 7.x  

This guide outlines the optimal configuration for running a modern Linux guest on a Linux host, leveraging paravirtualization, hugepages, and host-native I/O handling to reduce virtualization overhead.

---

## 1. VirtualBox GUI Configuration
Before starting the VM, apply these settings in the VirtualBox GUI:

* **System > Motherboard:**
    * chipset ICH9
    * check I/O ICPA
    * check UEFI.
* **System > Processor:** 
    * check Nested VT-x/AMD-V (if supported by CPU). Allocate at least 2-4 cores.
* **System > Acceleration:** 
    * Set Paravirtualization Interface to **KVM**.
    * check nested paging
* **Display > Screen:** * Video Memory: **128 MB** (maximum allowed in GUI).
  * Check **Enable 3D Acceleration**.
  * Graphics Controller: **VMSVGA**.
* **Storage:** * Add a new **VirtIO-SCSI** controller.
  * Move the virtual disk (`.vdi`) to this controller.
  * Check **Use Host I/O Cache**.
* **Network:** Set Adapter Type to **Paravirtualized Network (virtio-net)**.

---

## 2. Host OS Tuning (Ubuntu 24.04)

### A. Enable HugePages (Large Pages)
HugePages reduce the CPU's memory management overhead by allocating RAM in 2MB chunks instead of the default 4KB.

1. Find your `vboxusers` group ID:
   ```bash
   getent group vboxusers
   ```
2. Edit your sysctl configuration:
   ```bash
   sudo nano /etc/sysctl.conf
   ```
3. Add the following lines (adjust `vm.nr_hugepages` based on how much RAM you are giving the VM; e.g., 2048 pages = 4GB):
   ```text
   vm.nr_hugepages = 2048
   vm.hugetlb_shm_group = <YOUR_VBOXUSERS_GROUP_ID>
   ```
4. Apply the changes:
   ```bash
   sudo sysctl -p
   ```

---

## 3. Advanced VirtualBox CLI Tuning
Run these commands on the **Host OS** while the VM is powered off to apply settings not available in the GUI. *(Replace `"Ubuntu_26"` with the exact name of your VM).*

**Enable Large Pages for the VM:**
```bash
VBoxManage modifyvm "Ubuntu_26" --largepages on
```

**Pass-through Host CPU Architecture (enables AVX/AES instructions):**
```bash
VBoxManage modifyvm "Ubuntu_26" --cpu-profile "host"
```

**Force 256MB VRAM (Bypasses GUI 128MB Limit for smoother UI):**
```bash
VBoxManage modifyvm "Ubuntu_26" --vram 256
```

---

## 4. Guest OS Tuning (Ubuntu 26.04)

### A. Lean Guest Additions Installation
Instead of installing the bloated `build-essential` package, install only the exact dependencies needed to compile VirtualBox kernel modules:

```bash
sudo apt update
sudo apt install gcc make bzip2 linux-headers-$(uname -r)
```
*(Insert the Guest Additions CD via the VirtualBox menu and run the installer script).*

### B. I/O Scheduler Optimization
Because the Host OS is already caching and scheduling disk writes, having the Guest OS do it is redundant. Set the Guest's scheduler to `none`.

1. Create a udev rule to make it permanent:
   ```bash
   sudo nano /etc/udev/rules.d/60-virtio-scheduler.rules
   ```
2. Add this line:
   ```text
   ACTION=="add|change", KERNEL=="sd[a-z]|vd[a-z]", ATTR{queue/scheduler}="none"
   ```
3. reboot and verify
   ```
   cat /sys/block/<block device name>/queue/scheduler
   ```   

### C. Fix GRUB "Invalid Environment Block" Warning
VirtualBox's handling of sparse files via Host I/O Caching can corrupt the 1024-byte `grubenv` file, causing a "press any key to continue" warning on boot. 

Run the following commands inside the Guest OS to force-create a physically thick file:

1. Install required EFI tools (often missing from default minimal installs):
   ```bash
   sudo apt install grub-efi-amd64-bin grub-efi-amd64-signed
   ```
2. Reinstall GRUB EFI modules:
   ```bash
   sudo grub-install --target=x86_64-efi --recheck
   ```
3. Rebuild the grubenv block from physical zeros:
   ```bash
   sudo rm /boot/grub/grubenv
   sudo dd if=/dev/zero of=/boot/grub/grubenv bs=1024 count=1
   sudo grub-editenv /boot/grub/grubenv create
   ```
4. Sync to disk and update GRUB:
   ```bash
   sync
   sudo update-grub
   ```

Reboot the VM. It should now boot silently and operate with near-native hardware acceleration and minimal I/O latency.