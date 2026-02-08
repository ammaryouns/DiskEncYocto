#!/bin/bash

# Function to display usage and exit
usage() {
    echo "Usage: $0 <key_file> <luks_device> <mapped_name> <mount_point>"
    echo "  key_file: Path to the decrypted key file."
    echo "  luks_device: Encrypted LUKS device (e.g., /dev/mmcblk2p7)."
    echo "  mapped_name: Name for the mapped device (e.g., datafs_enc_mapped)."
    echo "  mount_point: Desired mount point (e.g., /media/datafs_enc)."
    exit 1
}

# Check if all arguments are provided
if [ "$#" -ne 4 ]; then
    usage
fi

# Arguments
KEY_FILE="$1"          # Decrypted key file passed as an argument
LUKS_DEVICE="$2"       # Encrypted device
MAPPED_NAME="$3"       # Name for the mapped device
MOUNT_POINT="$4"       # Mount point

# Check if dm-crypt is loaded
if ! lsmod | grep -q dm_crypt; then
    echo "dm-crypt module is not loaded. Loading..."
    if ! modprobe dm_crypt; then
        echo "Failed to load dm-crypt module. Exiting."
        exit 1
    fi
    echo "dm-crypt module loaded."
else
    echo "dm-crypt module is already loaded."
fi

# Check if the device is LUKS
if ! cryptsetup isLuks "$LUKS_DEVICE"; then
    echo "Error: The specified device is not a LUKS device."
    exit 1
fi

# Check if the mount point exists; create it if it does not
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount point at $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT" || { echo "Failed to create mount point. Exiting."; exit 1; }
fi

# Check if the encrypted partition is already mapped
if ! lsblk | grep -q "$MAPPED_NAME"; then
    echo "Opening LUKS device..."
    if ! cryptsetup open --type luks2 "$LUKS_DEVICE" "$MAPPED_NAME" --key-file="$KEY_FILE"; then
        echo "Failed to open LUKS device. Check if the device exists and if you have the correct passphrase."
        exit 1
    fi
else
    echo "LUKS device is already mapped as $MAPPED_NAME."
fi

# Check if the mapped device exists before mounting
if [ ! -e /dev/mapper/"$MAPPED_NAME" ]; then
    echo "Error: Mapped device /dev/mapper/$MAPPED_NAME does not exist. Exiting."
    exit 1
fi

# Mount the mapped device
echo "Mounting the mapped device..."
if ! mount /dev/mapper/"$MAPPED_NAME" "$MOUNT_POINT"; then
    echo "Failed to mount the encrypted partition. Attempting to clean up."
    # Cleanup: Close the mapped device if it was opened
    if lsblk | grep -q "$MAPPED_NAME"; then
        echo "Closing the mapped device..."
        cryptsetup luksClose "$MAPPED_NAME" || echo "Failed to close the mapped device."
    fi
    exit 1
fi

echo "Encrypted partition mounted successfully..."
