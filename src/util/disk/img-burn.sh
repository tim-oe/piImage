#!/bin/bash

set -e

usage() {
  cat <<EOF
Usage: sudo $0 <disk.img> <target_device>

  Write a disk image file to a block device (e.g. USB drive or SD card).
  The target must be at least as large as the image.

Example:
  sudo $0 /backup/disk.img /dev/sdg
EOF
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "$1" || -z "$2" ]]; then
  usage
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Error: this script must be run as root (sudo)"
  exit 1
fi

DISK_IMG="$1"
TARGET="$2"
PRE_CHECK_PASS=true

# ─────────────────────────────────────────────
# Validate inputs
# ─────────────────────────────────────────────
if [[ ! -f "$DISK_IMG" ]]; then
  echo "Error: Image file '$DISK_IMG' not found"
  exit 1
fi

if [[ ! -b "$TARGET" ]]; then
  echo "Error: '$TARGET' is not a block device"
  exit 1
fi

IMG_BYTES=$(stat -c%s "$DISK_IMG")
TARGET_BYTES=$(blockdev --getsize64 "$TARGET")

echo ""
echo "════════════════════════════════════════════"
echo " Disk Restore"
echo " Image  : $DISK_IMG ($(numfmt --to=iec $IMG_BYTES))"
echo " Target : $TARGET ($(numfmt --to=iec $TARGET_BYTES))"
echo "════════════════════════════════════════════"

# ─────────────────────────────────────────────
# Check target is large enough
# ─────────────────────────────────────────────
if [[ "$TARGET_BYTES" -lt "$IMG_BYTES" ]]; then
  echo ""
  echo "Error: Target drive ($(numfmt --to=iec $TARGET_BYTES)) is smaller than the image ($(numfmt --to=iec $IMG_BYTES))"
  exit 1
fi

if [[ "$TARGET_BYTES" -gt "$IMG_BYTES" ]]; then
  echo ""
  echo "  Note: Target drive is larger than the image."
  echo "  Unallocated space can be expanded after restore using disk_resize.sh on the Pi."
fi

# ─────────────────────────────────────────────
# Detect device type
# ─────────────────────────────────────────────
TARGET_BASE=$(basename "$TARGET")
DEVICE_TYPE="disk"

# Check if SD card (mmcblk) or USB flash drive
if [[ "$TARGET_BASE" == mmcblk* ]]; then
  DEVICE_TYPE="sdcard"
elif [[ -f /sys/block/$TARGET_BASE/removable ]] && \
     [[ "$(cat /sys/block/$TARGET_BASE/removable)" == "1" ]]; then
  # Check if it's USB
  SYSPATH=$(readlink -f /sys/block/$TARGET_BASE)
  if echo "$SYSPATH" | grep -qi "usb"; then
    DEVICE_TYPE="usb"
  fi
fi

echo ""
echo "    Device type : $DEVICE_TYPE"

# ─────────────────────────────────────────────
# PRE-WRITE: SMART health check
# ─────────────────────────────────────────────
echo ""
echo ">>> [1/5] Checking target drive health (SMART)..."

if [[ "$DEVICE_TYPE" == "sdcard" || "$DEVICE_TYPE" == "usb" ]]; then
  echo "    Device is a $DEVICE_TYPE — SMART not supported, skipping."
elif command -v smartctl &>/dev/null; then
  SMART_STATUS=$(smartctl -H "$TARGET" 2>/dev/null | grep -i "overall-health" || echo "SMART not available for this device")
  echo "    $SMART_STATUS"
  if echo "$SMART_STATUS" | grep -qi "FAILED"; then
    echo ""
    echo "    ERROR: Drive is reporting SMART failure — aborting."
    echo "    This drive should be replaced before use."
    exit 1
  fi

  # Show key SMART attributes
  echo ""
  echo "    Key SMART attributes:"
  smartctl -A "$TARGET" 2>/dev/null | grep -E "Reallocated_Sector|Current_Pending|Offline_Uncorrectable" | \
    awk '{printf "      %-35s %s\n", $2, $10}' || echo "      (not available)"

  # Warn if any concerning attributes are non-zero
  PENDING=$(smartctl -A "$TARGET" 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}' || echo "0")
  UNCORRECTABLE=$(smartctl -A "$TARGET" 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $10}' || echo "0")

  if [[ "$PENDING" -gt 0 ]]; then
    echo ""
    echo "    WARNING: $PENDING pending sector(s) detected — drive may be failing"
    PRE_CHECK_PASS=false
  fi
  if [[ "$UNCORRECTABLE" -gt 0 ]]; then
    echo ""
    echo "    WARNING: $UNCORRECTABLE uncorrectable sector(s) detected — drive is failing"
    PRE_CHECK_PASS=false
  fi
else
  echo "    smartmontools not installed — skipping SMART check"
  echo "    Install with: sudo apt install smartmontools"
fi

# ─────────────────────────────────────────────
# PRE-WRITE: Bad block scan
# ─────────────────────────────────────────────
echo ""
echo ">>> [2/5] Bad block scan..."
read -rp "  Run bad block scan before writing? This can take a long time. (yes/no): " RUN_BADBLOCKS
if [[ "$RUN_BADBLOCKS" == "yes" ]]; then
  echo "  Scanning $TARGET for bad blocks..."
  BADBLOCK_OUT=$(badblocks -v -s "$TARGET" 2>&1)
  echo "$BADBLOCK_OUT"
  BAD_COUNT=$(echo "$BADBLOCK_OUT" | grep -oP '\d+(?= bad blocks found)' || echo "0")
  if [[ "$BAD_COUNT" -gt 0 ]]; then
    echo ""
    echo "  ERROR: $BAD_COUNT bad blocks found on $TARGET"
    PRE_CHECK_PASS=false
  else
    echo "  No bad blocks found."
  fi
else
  echo "  Skipping bad block scan."
fi

# ─────────────────────────────────────────────
# Abort if pre-checks failed
# ─────────────────────────────────────────────
if [[ "$PRE_CHECK_PASS" == false ]]; then
  echo ""
  echo "════════════════════════════════════════════"
  echo " PRE-WRITE CHECKS FAILED"
  echo " Drive health issues detected — see above."
  echo " Recommend replacing the drive before proceeding."
  echo ""
  read -rp " Override and write anyway? (yes/no): " OVERRIDE
  if [[ "$OVERRIDE" != "yes" ]]; then
    echo " Aborted."
    exit 1
  fi
  echo " Overriding — proceeding with write..."
fi

# ─────────────────────────────────────────────
# Confirm before overwriting
# ─────────────────────────────────────────────
echo ""
echo ">>> [3/5] Confirm write..."
echo ""
echo "  WARNING: ALL data on $TARGET will be overwritten."
echo ""
lsblk "$TARGET"
echo ""
read -rp "  Type YES to confirm: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

# ─────────────────────────────────────────────
# Write image to target drive
# ─────────────────────────────────────────────
echo ""
echo ">>> [4/5] Writing image to $TARGET..."
dd if="$DISK_IMG" of="$TARGET" bs=4M status=progress conv=fsync
echo "    Write complete."

# Re-read partition table
echo ""
echo "    Re-reading partition table..."
partprobe "$TARGET"
sleep 1

# ─────────────────────────────────────────────
# POST-WRITE: Verify filesystems
# ─────────────────────────────────────────────
VERIFY_PASS=true

echo ""
echo ">>> [5/5] Post-write verification..."
echo ""

# ── Partition table ──
echo "--- Partition Table ---"
parted "$TARGET" print
echo ""

# ── Filesystem checks per partition ──
echo "--- Filesystem Checks ---"
for PART in $(lsblk -ln -o NAME "$TARGET" | grep -v "^$(basename $TARGET)$"); do
  PART_DEV="/dev/$PART"
  FSTYPE=$(blkid -s TYPE -o value "$PART_DEV" 2>/dev/null || echo "")

  echo ""
  echo "  Partition: $PART_DEV  (${FSTYPE:-unknown})"

  case "$FSTYPE" in
    ext2|ext3|ext4)
      echo "  Running e2fsck..."
      if e2fsck -f -v "$PART_DEV" 2>&1; then
        echo "  e2fsck: OK"
      else
        echo "  e2fsck: Issues found on $PART_DEV"
        VERIFY_PASS=false
      fi
      ;;
    vfat)
      echo "  Running dosfsck..."
      if dosfsck -t -v "$PART_DEV" 2>&1; then
        echo "  dosfsck: OK"
      else
        echo "  dosfsck: Issues found on $PART_DEV"
        VERIFY_PASS=false
      fi
      ;;
    "")
      echo "  No filesystem detected — skipping"
      ;;
    *)
      echo "  Unsupported filesystem type '$FSTYPE' — skipping fsck"
      ;;
  esac
done

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Restore complete!"
echo ""
lsblk "$TARGET"
echo ""
echo " UUIDs:"
for PART in $(lsblk -ln -o NAME "$TARGET" | grep -v "^$(basename $TARGET)$"); do
  blkid "/dev/$PART" 2>/dev/null || true
done
echo ""

if [[ "$VERIFY_PASS" == true ]]; then
  echo " Post-write verification : PASSED"
else
  echo " Post-write verification : FAILED — review errors above"
fi

echo ""
if [[ "$TARGET_BYTES" -gt "$IMG_BYTES" ]]; then
  echo " Target drive is larger than the image."
  echo " Run disk_resize.sh on the Pi to expand:"
  echo "   sudo ./disk_resize.sh <device>"
  echo ""
fi

echo " To mount partitions:"
for PART in $(lsblk -ln -o NAME "$TARGET" | grep -v "^$(basename $TARGET)$"); do
  PART_NUM=$(echo "$PART" | grep -o '[0-9]*$')
  echo "   sudo mount /dev/${PART} /mnt/part${PART_NUM}"
done
echo "════════════════════════════════════════════"