#!/bin/bash

# Check that the correct number of arguments are provided
if [ "$#" -ne 4 ]; then
    echo -e "Usage: $0 <wic_image_path> <partition_label> <KEY_FILE> <cipher>"
    exit 1
fi

# Variables
WIC_IMAGE_LINK=$1  # Path to the .wic image
PARTITION_LABEL=$2  # The label of the partition to be encrypted (e.g., datafs)
KEY_FILE=$3  # Path to the LUKS key file
CIPHER=$4  # Cipher to use for encryption (e.g., aes-256-cbc)

MOUNT_POINT="/build/mnt/data"
TEMP_DIR="/build/tmp/enc_storage_data"

echo -e "WIC_Image 	: $WIC_IMAGE_LINK"  
echo -e "Partition 	: $PARTITION_LABEL"
echo -e "KEY_FILE	: $KEY_FILE"
echo -e "CIPHER	: $CIPHER"

if [ -L "$WIC_IMAGE_LINK" ]; then
    WIC_IMAGE=$(readlink -f "$WIC_IMAGE_LINK")
    echo "The symbolic link points to: $WIC_IMAGE"
else
    echo "$WIC_IMAGE_LINK is not a symbolic link."
    WIC_IMAGE=$WIC_IMAGE_LINK 
fi


# Step 1: Attach the .wic image as a loopback device
LOOP_DEV=$(losetup --show -fP "$WIC_IMAGE") ; sleep 5
if [ $? -ne 0 ]; then
    echo "Failed to set up loop device."
    exit 1
else
    echo "Loop device setup to $LOOP_DEV"
fi

# Step 2: Find the partition with the label (e.g., datafs) using blkid
PARTITION_DEV=$(blkid "${LOOP_DEV}"* | grep "LABEL=\"$PARTITION_LABEL\"" | awk -F ':' '{print $1}')

echo "PARTITION_DEV: $PARTITION_DEV"

# If partition is not found, exit with an error
if [ -z "$PARTITION_DEV" ]; then
    echo "Error: Partition with label $PARTITION_LABEL not found in $WIC_IMAGE"
    losetup -d "$LOOP_DEV"  # Clean up loop device
    exit 1
fi

mkdir -p $MOUNT_POINT
if [ $? -ne 0 ]; then
    echo "Error: Unable to create Dir : $MOUNT_POINT."
    losetup -d "$LOOP_DEV"
    exit 1
fi
# Step 3: Check if the partition has data
mount $PARTITION_DEV $MOUNT_POINT
if [ $? -ne 0 ]; then
    echo "Error: Unable to Mount Partition to : $MOUNT_POINT."
    losetup -d "$LOOP_DEV"
    exit 1
fi

# Step 4: Check for Data
if [ "$(ls -A "$MOUNT_POINT")" ]; then
    echo "Data exists in the partition."
    # Create temporary directory for existing data
    mkdir -p "$TEMP_DIR"
    echo "Copying existing data from $PARTITION_DEV to $TEMP_DIR."
    cp -a "$MOUNT_POINT/"* "$TEMP_DIR/"
else
    echo "No data found in the partition."
fi

# Step 6: Unmount the temporary mount point
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "Error: Unable to Un-Mount Partition to : $MOUNT_POINT."
    losetup -d "$LOOP_DEV"
    exit 1
fi

# Step 7: Encrypt the partition using cryptsetup
cryptsetup luksFormat "$PARTITION_DEV" --type luks2 --key-file "$KEY_FILE" --cipher "$CIPHER" --pbkdf-memory=256000 --batch-mode

# Step 8: Open the encrypted partition
cryptsetup luksOpen "$PARTITION_DEV" datafs_enc --key-file "$KEY_FILE"

# Step 9: Format the encrypted partition
mkfs.ext4 /dev/mapper/datafs_enc

# Step 10: Create a temporary mount point and mount the encrypted partition
mount /dev/mapper/datafs_enc "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "Error: Unable to Mount Partition to :  /dev/mapper/datafs_enc."
    losetup -d "$LOOP_DEV"
    exit 1
fi
# Step 11: Copy data back from the temporary directory to the encrypted partition
if [ -d "$TEMP_DIR" ]; then
    echo "Copying data from $TEMP_DIR to $MOUNT_DIR."
    cp -a "$TEMP_DIR/"* "$MOUNT_POINT/"
else
    echo "Warning: Temporary directory $TEMP_DIR does not exist."
fi

# Step 12: Unmount the encrypted partition
umount "$MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "Error: Unable to Mount :  $MOUNT_POINT."
    losetup -d "$LOOP_DEV"
    exit 1
fi
# Step 13: Close the encrypted volume
cryptsetup luksClose datafs_enc

# Step 14: Detach the loopback device
losetup -d "$LOOP_DEV"

# Cleanup
rm -rf "$TEMP_DIR"

# Step 15: Check if the .bz2 file exists and delete it
if [ -f "${WIC_IMAGE}.bz2" ]; then
    echo "Found ${WIC_IMAGE}.bz2. Deleting it..."-
    rm "${WIC_IMAGE}.bz2"        
    if [ $? -ne 0 ]; then
        echo "Warning: Error deleting ${WIC_IMAGE}.bz2. Proceeding anyway."
        exit 1
    fi
    
    # Step 15: Create a new .bz2 compressed file from the .wic image
    echo "Compressing ${WIC_IMAGE} to ${WIC_IMAGE}.bz2 ..."
    bzip2 -k -f "${WIC_IMAGE}"  # Compress the .wic file, keeping the original
    if [ $? -ne 0 ]; then
        echo "Error: Compression failed for ${WIC_IMAGE}. Please check the file."
        exit 1
    fi
fi

echo "Partition $PARTITION_LABEL successfully encrypted and data copied back."
