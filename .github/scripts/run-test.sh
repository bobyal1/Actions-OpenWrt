#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Starting UBIFS and NANDSIm test..."

# Load the nandsim module with device parameters
# Note: These parameters define the simulated NAND geometry. 
# They must match the UBIFS image you intend to use.
echo "Loading nandsim module..."
modprobe nandsim first_id_byte=0xec second_id_byte=0xd3 third_id_byte=0x51 fourth_id_byte=0x95

# Verify that the MTD device was created
dmesg | grep "nand"

# Create a device node for mtd0
# Udev may not run in the container, so we create the node manually
echo "Creating /dev/mtd0 device node..."
mknod /dev/mtd0 c 90 0

# Create a sample file to be included in the ubifs image
echo "Creating sample file for ubifs image..."
echo "Hello from GitHub Actions!" > hello.txt

# Create an ubifs image
echo "Creating ubifs image..."
mkfs.ubifs -r . -m 2048 -e 129024 -c 100 -o ubifs.img

# Create the UBI image configuration file
cat <<EOF > ubinize.cfg
[ubifs]
mode=ubi
image=ubifs.img
vol_id=0
vol_size=20MiB
vol_type=dynamic
vol_name=test_volume
EOF

# Create the UBI image
echo "Creating UBI image..."
ubinize -o ubi.img -m 2048 -p 128KiB -s 512 ubinize.cfg

# Use nandwrite to write the UBI image to the simulated NAND device
echo "Writing UBI image to nandsim device..."
nandwrite -p /dev/mtd0 ubi.img

# Load the ubi and ubifs modules
echo "Loading ubi and ubifs modules..."
modprobe ubi

# Attach the UBI device to the MTD device
echo "Attaching UBI device to MTD device..."
ubiattach /dev/ubi_ctrl -m 0

# Verify the UBI device
ls /dev/ubi*

# Mount the UBIFS volume
echo "Mounting UBIFS volume..."
mkdir -p /mnt/ubifs
mount -t ubifs ubi0:test_volume /mnt/ubifs

# Verify contents and check for success
echo "Verifying mounted data..."
ls -l /mnt/ubifs
cat /mnt/ubifs/hello.txt

# Unmount and detach cleanly
echo "Cleaning up..."
umount /mnt/ubifs
ubidetach /dev/ubi_ctrl -m 0
rmmod ubi
rmmod nandsim

echo "Test successful!"

