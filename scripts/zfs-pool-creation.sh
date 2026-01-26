#!/usr/bin/env bash

# This script creates the ZFS pools BUZZ and WOODY for the SKYLAB homelab.
# WARNING: This script will format the specified drives. Data will be lost.

# 1. Create the high-speed SSD pool (BUZZ)
# Using Realtek RTL9210B (sdb)
echo "Creating pool BUZZ..."
sudo zpool create -f -o ashift=12 \
  -O compression=zstd \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -O autotrim=on \
  BUZZ usb-Realtek_RTL9210B-CG_012345678944-0:0

# 2. Create the redundant HDD Mirror pool (WOODY)
# Using ASMT ASM1352R (sdc, sdd)
echo "Creating pool WOODY (Mirror)..."
sudo zpool create -f -o ashift=12 \
  -O compression=zstd \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  WOODY mirror \
  usb-ASMT_ASM1352R-PM_AAAABBBB0003-0:0 \
  usb-ASMT_ASM1352R-PM_AAAABBBB0003-0:1

# 3. Create the datasets for logical isolation
echo "Creating datasets..."
sudo zfs create BUZZ/immich
sudo zfs create WOODY/photos

echo "ZFS setup complete."
sudo zpool status
