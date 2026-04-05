#!/bin/bash

set -e

usage() {
  cat <<EOF
Usage: sudo $0 <device>

    Resize the last partition to fill the drive.
    update fstab and cmdline.txt if partitionUUIDs changed
  
Example:
  sudo $0 /dev/sda
EOF
}

# ─────────────────────────────────────────────
# Usage: sudo ./disk_resize.sh <device>
# Example: sudo ./disk_resize.sh /dev/sda
#
# Run this on the Pi after restoring the image to a new drive.
# It will:
#   1. Capture existing UUIDs before resize
#   2. Resize the last partition to fill the drive
#   3. Run e2fsck and resize2fs
#   4. Fix UUIDs in fstab and cmdline.txt if they changed
# ─────────────────────────────────────────────

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  usage
  exit 0
fi

if [[ -z "$1" ]]; then
  usage
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  echo "Error: this script must be run as root (sudo)"
  exit 1
fi

DEVICE="$1"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: '$DEVICE' is not a block device"
  exit 1
fi

# ─────────────────────────────────────────────
# Detect partition naming style
# mmcblk/nvme use p prefix, sda style does not
# ─────────────────────────────────────────────
if [[ "$DEVICE" == *"mmcblk"* ]] || [[ "$DEVICE" == *"nvme"* ]]; then
  BOOT_PART="${DEVICE}p1"
  ROOT_PART="${DEVICE}p2"
else
  BOOT_PART="${DEVICE}1"
  ROOT_PART="${DEVICE}2"
fi

echo ""
echo "════════════════════════════════════════════"
echo " Disk Resize and UUID Fix"
echo " Device     : $DEVICE"
echo " Boot part  : $BOOT_PART"
echo " Root part  : $ROOT_PART"
echo "════════════════════════════════════════════"

# Validate partitions exist
if [[ ! -b "$BOOT_PART" ]]; then
  echo "Error: Boot partition $BOOT_PART not found"
  exit 1
fi

if [[ ! -b "$ROOT_PART" ]]; then
  echo "Error: Root partition $ROOT_PART not found"
  exit 1
fi

# ─────────────────────────────────────────────
# Step 1: Capture UUIDs BEFORE resize
# ─────────────────────────────────────────────
echo ""
echo ">>> [1/5] Capturing UUIDs before resize..."

BOOT_UUID_BEFORE=$(blkid -s UUID -o value "$BOOT_PART" 2>/dev/null || echo "")
BOOT_PARTUUID_BEFORE=$(blkid -s PARTUUID -o value "$BOOT_PART" 2>/dev/null || echo "")
ROOT_UUID_BEFORE=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null || echo "")
ROOT_PARTUUID_BEFORE=$(blkid -s PARTUUID -o value "$ROOT_PART" 2>/dev/null || echo "")

echo "    Boot UUID     : $BOOT_UUID_BEFORE"
echo "    Boot PARTUUID : $BOOT_PARTUUID_BEFORE"
echo "    Root UUID     : $ROOT_UUID_BEFORE"
echo "    Root PARTUUID : $ROOT_PARTUUID_BEFORE"

# ─────────────────────────────────────────────
# Step 2: Check available space
# ─────────────────────────────────────────────
echo ""
echo ">>> [2/5] Checking available space..."

DISK_BYTES=$(blockdev --getsize64 "$DEVICE")
ROOT_END=$(parted -m "$DEVICE" unit B print | grep "^2:" | cut -d: -f3 | tr -d 'B')
AVAILABLE=$((DISK_BYTES - ROOT_END))

echo "    Disk size      : $(numfmt --to=iec $DISK_BYTES)"
echo "    Root part end  : $(numfmt --to=iec $ROOT_END)"
echo "    Unallocated    : $(numfmt --to=iec $AVAILABLE)"

if [[ "$AVAILABLE" -lt 1048576 ]]; then
  echo ""
  echo "    Nothing to expand — partition already fills the drive."
  exit 0
fi

echo ""
echo "  WARNING: This will resize $ROOT_PART on $DEVICE"
lsblk "$DEVICE"
echo ""
read -rp "  Type YES to confirm: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

# ─────────────────────────────────────────────
# Step 3: Resize partition and filesystem
# ─────────────────────────────────────────────
echo ""
echo ">>> [3/5] Resizing partition to fill drive..."
parted "$DEVICE" resizepart 2 100%
echo "    Partition resized."

echo ""
echo ">>> [4/5] Running e2fsck and resize2fs..."
e2fsck -f "$ROOT_PART"
resize2fs "$ROOT_PART"
echo "    Filesystem resized."

# ─────────────────────────────────────────────
# Step 4: Capture UUIDs AFTER resize
# ─────────────────────────────────────────────
echo ""
echo ">>> [5/5] Checking UUIDs after resize..."

BOOT_UUID_AFTER=$(blkid -s UUID -o value "$BOOT_PART" 2>/dev/null || echo "")
BOOT_PARTUUID_AFTER=$(blkid -s PARTUUID -o value "$BOOT_PART" 2>/dev/null || echo "")
ROOT_UUID_AFTER=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null || echo "")
ROOT_PARTUUID_AFTER=$(blkid -s PARTUUID -o value "$ROOT_PART" 2>/dev/null || echo "")

echo "    Boot UUID     : $BOOT_UUID_AFTER"
echo "    Boot PARTUUID : $BOOT_PARTUUID_AFTER"
echo "    Root UUID     : $ROOT_UUID_AFTER"
echo "    Root PARTUUID : $ROOT_PARTUUID_AFTER"

UUID_CHANGED=false
if [[ "$ROOT_UUID_BEFORE" != "$ROOT_UUID_AFTER" ]] || \
   [[ "$ROOT_PARTUUID_BEFORE" != "$ROOT_PARTUUID_AFTER" ]] || \
   [[ "$BOOT_UUID_BEFORE" != "$BOOT_UUID_AFTER" ]] || \
   [[ "$BOOT_PARTUUID_BEFORE" != "$BOOT_PARTUUID_AFTER" ]]; then
  UUID_CHANGED=true
  echo ""
  echo "    UUIDs changed — will update fstab and cmdline.txt"
else
  echo ""
  echo "    UUIDs unchanged — no further fixes needed"
fi

# ─────────────────────────────────────────────
# Step 5: Fix fstab and cmdline.txt if needed
# ─────────────────────────────────────────────
if [[ "$UUID_CHANGED" == true ]]; then

  # Mount partitions
  MNT_BOOT=$(mktemp -d)
  MNT_ROOT=$(mktemp -d)
  mount "$BOOT_PART" "$MNT_BOOT"
  mount "$ROOT_PART" "$MNT_ROOT"

  # ── Fix fstab ──
  FSTAB="$MNT_ROOT/etc/fstab"
  if [[ -f "$FSTAB" ]]; then
    echo ""
    echo "    Fixing fstab..."
    echo "    Before:"
    cat "$FSTAB"

    # Fix boot partition UUID in fstab
    if [[ -n "$BOOT_UUID_BEFORE" && -n "$BOOT_UUID_AFTER" && \
          "$BOOT_UUID_BEFORE" != "$BOOT_UUID_AFTER" ]]; then
      sed -i "s/UUID=$BOOT_UUID_BEFORE/UUID=$BOOT_UUID_AFTER/g" "$FSTAB"
    fi

    # Fix root partition UUID in fstab
    if [[ -n "$ROOT_UUID_BEFORE" && -n "$ROOT_UUID_AFTER" && \
          "$ROOT_UUID_BEFORE" != "$ROOT_UUID_AFTER" ]]; then
      sed -i "s/UUID=$ROOT_UUID_BEFORE/UUID=$ROOT_UUID_AFTER/g" "$FSTAB"
    fi

    # Fix PARTUUIDs in fstab
    if [[ -n "$BOOT_PARTUUID_BEFORE" && -n "$BOOT_PARTUUID_AFTER" && \
          "$BOOT_PARTUUID_BEFORE" != "$BOOT_PARTUUID_AFTER" ]]; then
      sed -i "s/PARTUUID=$BOOT_PARTUUID_BEFORE/PARTUUID=$BOOT_PARTUUID_AFTER/g" "$FSTAB"
    fi

    if [[ -n "$ROOT_PARTUUID_BEFORE" && -n "$ROOT_PARTUUID_AFTER" && \
          "$ROOT_PARTUUID_BEFORE" != "$ROOT_PARTUUID_AFTER" ]]; then
      sed -i "s/PARTUUID=$ROOT_PARTUUID_BEFORE/PARTUUID=$ROOT_PARTUUID_AFTER/g" "$FSTAB"
    fi

    echo "    After:"
    cat "$FSTAB"
  else
    echo "    Warning: fstab not found at $FSTAB"
  fi

  # ── Fix cmdline.txt ──
  # Check both possible locations
  for CMDLINE in "$MNT_BOOT/cmdline.txt" "$MNT_BOOT/firmware/cmdline.txt"; do
    if [[ -f "$CMDLINE" ]]; then
      echo ""
      echo "    Fixing $CMDLINE..."
      echo "    Before: $(cat $CMDLINE)"

      if [[ -n "$ROOT_PARTUUID_BEFORE" && -n "$ROOT_PARTUUID_AFTER" && \
            "$ROOT_PARTUUID_BEFORE" != "$ROOT_PARTUUID_AFTER" ]]; then
        sed -i "s/PARTUUID=$ROOT_PARTUUID_BEFORE/PARTUUID=$ROOT_PARTUUID_AFTER/g" "$CMDLINE"
      fi

      if [[ -n "$ROOT_UUID_BEFORE" && -n "$ROOT_UUID_AFTER" && \
            "$ROOT_UUID_BEFORE" != "$ROOT_UUID_AFTER" ]]; then
        sed -i "s/UUID=$ROOT_UUID_BEFORE/UUID=$ROOT_UUID_AFTER/g" "$CMDLINE"
      fi

      echo "    After : $(cat $CMDLINE)"
    fi
  done

  # Unmount
  umount "$MNT_BOOT"
  umount "$MNT_ROOT"
  rmdir "$MNT_BOOT" "$MNT_ROOT"
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Resize complete!"
echo ""
lsblk "$DEVICE"
echo ""
echo " Final UUIDs:"
blkid "$BOOT_PART"
blkid "$ROOT_PART"
echo ""
echo " Safe to reboot."
echo "════════════════════════════════════════════"