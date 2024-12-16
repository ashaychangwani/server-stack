#!/bin/bash

# Exclude the SSD hosting the OS (e.g., /dev/sda)
OS_DRIVE="/dev/sdc"

# Get all drives except the OS SSD
DRIVES=$(lsblk -d -o NAME | grep -E '^sd' | grep -v $(basename $OS_DRIVE))

# Check health for all drives
for DRIVE in $DRIVES; do
    echo "Checking health for /dev/$DRIVE..."
    sudo smartctl -H /dev/$DRIVE
    echo "SMART stats for /dev/$DRIVE:"
    sudo smartctl -a /dev/$DRIVE | grep -i 'health\|reallocated\|pending\|uncorrectable'
    echo "---------------------------------------"
done
