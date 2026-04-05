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
  echo "  Unallocated space can be expanded after restore using gparted."
fi

# ─────────────────────────────────────────────
# Confirm before overwriting
# ─────────────────────────────────────────────
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
echo ">>> Writing image to $TARGET..."
dd if="$DISK_IMG" of="$TARGET" bs=4M status=progress conv=fsync
echo "    Write complete."

# ─────────────────────────────────────────────
# Re-read partition table
# ─────────────────────────────────────────────
echo ""
echo ">>> Re-reading partition table..."
partprobe "$TARGET"
sleep 1

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Restore complete!"
echo ""
lsblk "$TARGET"
echo ""

if [[ "$TARGET_BYTES" -gt "$IMG_BYTES" ]]; then
  echo " Target drive is larger than the image."
  echo " Use gparted to validate and expand partitions:"
  echo "   sudo gparted $TARGET"
  echo ""
fi

echo " To mount partitions:"
for PART in $(lsblk -ln -o NAME "$TARGET" | grep -v "^$(basename $TARGET)$"); do
  PART_NUM=$(echo "$PART" | grep -o '[0-9]*$')
  echo "   sudo mount /dev/${PART} /mnt/part${PART_NUM}"
done
echo "════════════════════════════════════════════"