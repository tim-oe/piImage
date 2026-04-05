#!/bin/bash

set -e

usage() {
  cat <<EOF
Usage: sudo $0 <device> <output_dir>

  Create a disk image and partclone backups of each partition from <device>
  into <output_dir>.

Example:
  sudo $0 /dev/sdf /backup
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

DEVICE="$1"
OUTDIR="$2"
DISK_IMG="$OUTDIR/disk.img"

if [[ ! -b "$DEVICE" ]]; then
  echo "Error: $DEVICE is not a block device"
  exit 1
fi

mkdir -p "$OUTDIR"

# ─────────────────────────────────────────────
# Step 1: Get disk size in bytes and create image file
# ─────────────────────────────────────────────
echo ""
echo ">>> [1/5] Getting disk size and creating image file..."

DISK_BYTES=$(blockdev --getsize64 "$DEVICE")
echo "    Disk size: $DISK_BYTES bytes"
truncate -s "$DISK_BYTES" "$DISK_IMG"
echo "    Created: $DISK_IMG"

# ─────────────────────────────────────────────
# Step 2: Copy partition table
# ─────────────────────────────────────────────
echo ""
echo ">>> [2/5] Copying partition table..."

sfdisk -d "$DEVICE" | sfdisk "$DISK_IMG"
echo "    Partition table copied."

# ─────────────────────────────────────────────
# Step 3: Set up loop device
# ─────────────────────────────────────────────
echo ""
echo ">>> [3/5] Setting up loop device..."

LOOP=$(losetup -f)
losetup -fP "$DISK_IMG"
echo "    Loop device: $LOOP"

# Wait for partition devices to appear
sleep 1

# Confirm partitions are visible
PARTS=$(ls ${LOOP}p* 2>/dev/null)
if [[ -z "$PARTS" ]]; then
  echo "Error: No partitions found on $LOOP — check the image/partition table"
  losetup -d "$LOOP"
  exit 1
fi
echo "    Partitions found: $(echo $PARTS | tr '\n' ' ')"

# ─────────────────────────────────────────────
# Step 4: Image each partition with partclone
# ─────────────────────────────────────────────
echo ""
echo ">>> [4/5] Imaging partitions..."

# Get list of partitions on the source device
SOURCE_PARTS=$(lsblk -ln -o NAME,FSTYPE "$DEVICE" | grep -v "^$(basename $DEVICE) " )

while IFS= read -r line; do
  PART_NAME=$(echo "$line" | awk '{print $1}')
  FSTYPE=$(echo "$line" | awk '{print $2}')
  PART_DEV="/dev/$PART_NAME"
  PART_NUM=$(echo "$PART_NAME" | grep -o '[0-9]*$')
  PCL_FILE="$OUTDIR/part${PART_NUM}.pcl"

  echo ""
  echo "    Partition: $PART_DEV  Filesystem: $FSTYPE"

  case "$FSTYPE" in
    vfat|fat32|fat16)
      echo "    Using partclone.vfat..."
      partclone.vfat -c -s "$PART_DEV" -o "$PCL_FILE"
      ;;
    ext2|ext3|ext4)
      echo "    Using partclone.extfs..."
      partclone.extfs -c -s "$PART_DEV" -o "$PCL_FILE"
      ;;
    ntfs)
      echo "    Using partclone.ntfs..."
      partclone.ntfs -c -s "$PART_DEV" -o "$PCL_FILE"
      ;;
    btrfs)
      echo "    Using partclone.btrfs..."
      partclone.btrfs -c -s "$PART_DEV" -o "$PCL_FILE"
      ;;
    xfs)
      echo "    Using partclone.xfs..."
      partclone.xfs -c -s "$PART_DEV" -o "$PCL_FILE"
      ;;
    "")
      echo "    Warning: No filesystem detected on $PART_DEV, using dd fallback..."
      dd if="$PART_DEV" of="$PCL_FILE" bs=4M status=progress
      ;;
    *)
      echo "    Warning: Unsupported filesystem '$FSTYPE' on $PART_DEV, using dd fallback..."
      dd if="$PART_DEV" of="$PCL_FILE" bs=4M status=progress
      ;;
  esac

  echo "    Saved: $PCL_FILE"

done <<< "$SOURCE_PARTS"

# ─────────────────────────────────────────────
# Step 5: Restore each partition into loop device
# ─────────────────────────────────────────────
echo ""
echo ">>> [5/5] Restoring partitions into disk image..."

for PCL_FILE in "$OUTDIR"/part*.pcl; do
  PART_NUM=$(basename "$PCL_FILE" | grep -o '[0-9]*')
  LOOP_PART="${LOOP}p${PART_NUM}"

  echo ""
  echo "    Restoring $PCL_FILE -> $LOOP_PART"

  # dd fallback files won't work with partclone.restore, detect by checking header
  if partclone.info -s "$PCL_FILE" &>/dev/null; then
    partclone.restore -s "$PCL_FILE" -o "$LOOP_PART"
  else
    dd if="$PCL_FILE" of="$LOOP_PART" bs=4M status=progress
  fi

  echo "    Done: $LOOP_PART"
done

# ─────────────────────────────────────────────
# Done — print mount instructions
# ─────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Image created successfully!"
echo " Image file : $DISK_IMG"
echo " Loop device: $LOOP"
echo ""
echo " To mount partitions:"
for LOOP_PART in ${LOOP}p*; do
  PART_NUM=$(echo "$LOOP_PART" | grep -o '[0-9]*$')
  echo "   sudo mount ${LOOP_PART} /mnt/part${PART_NUM}"
done
echo ""
echo " To detach loop device when done:"
echo "   sudo losetup -d $LOOP"
echo "════════════════════════════════════════════"