#!/bin/bash
# Wait for GPS to provide valid time data before starting ntpsec
timeout=60
elapsed=0

echo "Waiting for GPS time data..."

# had instance where folder disapeared, possibly due to log2ram
if [ ! -d /var/log/ntpsec ]; then
  mkdir -p /var/log/ntpsec
  chown root:root /var/log/ntpsec
  chmod 755 /var/log/ntpsec
fi

while [ $elapsed -lt $timeout ]; do
  # Check if GPS device is available and responding
  if [ -c /dev/gps0 ] && gpsctl /dev/gps0 2>/dev/null | grep -q "NMEA0183"; then
	  echo "GPS device detected and responding"
	  # Check if PPS is also available
	  if [ -c /dev/pps0 ] && gpsctl /dev/pps0 2>/dev/null | grep -q "PPS"; then
		  echo "PPS device also available"
	  fi
	  # Give GPS a bit more time to get solid fix and time data
	  sleep 5
	  exit 0
  elif [ -c /dev/gps0 ]; then
	  echo "GPS device exists, waiting for it to respond..."
  else
	  echo "Waiting for GPS device /dev/gps0 to appear..."
  fi
  sleep 2
  elapsed=$((elapsed + 2))
done

echo "Warning: Timeout waiting for GPS, starting ntpsec anyway"
# Exit 0 so ntpsec starts even if GPS isn't ready yet
exit 0