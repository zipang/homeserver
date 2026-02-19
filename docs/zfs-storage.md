# ZFS Storage (BUZZ & WOODY)

This document describes the ZFS configuration used for high-performance and redundant storage on the SKYLAB homelab server.

## Overview
We use ZFS to manage storage on our external drives connected via USB-C (10Gbs USB 4). 
This provides superior data integrity, compression, and logical volume management compared to traditional partitions or BTRFS subvolumes.

*   **Pool `BUZZ`**: Single-disk pool on a 4TB SSD. Optimized for high-speed access (Immich database, active workspace).
*   **Pool `WOODY`**: Mirrored pool (RAID1) on two 12TB HDDs. Optimized for long-term redundant storage (Photos, Archives).

## Configuration Reference
*   [NixOS ZFS Options](https://search.nixos.org/options?query=boot.zfs)
*   [ZFS on NixOS Wiki](https://nixos.wiki/wiki/ZFS)

## ZFS Installation on Fedora

Because ZFS is not included into latest Fedora we have to install it from the OpenZFS releases page.

Instructions found on the [OpenZFS documentation](https://openzfs.github.io/openzfs-docs/Getting%20Started/Fedora/index.html)

```
# Add ZFS package from external repo:
dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm

# Install kernel headers:
sudo dnf install -y kernel-devel-$(uname -r | awk -F'-' '{print $1}')

# Install ZFS packages:
sudo dnf install zfs

# Load kernel module:
sudo modprobe zfs
```

## Initial ZFS pools Creation

To ensure stability across reboots, pools are created using unique disk IDs from `/dev/disk/by-id/`.

### BUZZ (SSD)
```bash
sudo zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  BUZZ <disk-id>
```

### WOODY (HDD Mirror)
```bash
sudo zpool create -f -o ashift=12 \
  -O compression=zstd \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  WOODY mirror <disk-id-1> <disk-id-2>
```

## Datasets
Instead of directories, we use ZFS datasets for isolation. We set them to `mountpoint=legacy` to let NixOS manage the mounting via `systemd`.

```bash
# Set legacy mode on pools
sudo zfs set mountpoint=legacy BUZZ
sudo zfs set mountpoint=legacy WOODY

# Create datasets and set to legacy mode
sudo zfs create BUZZ/immich
sudo zfs set mountpoint=legacy BUZZ/immich

sudo zfs create WOODY/photos
sudo zfs set mountpoint=legacy WOODY/photos
```

## NixOS Integration

ZFS support and services are enabled in the host configuration:
```nix
boot.supportedFilesystems = [ "zfs" ];
networking.hostId = "8425e349"; # Required for ZFS
boot.zfs.extraPools = [ "BUZZ" "WOODY" ];
services.zfs.autoScrub.enable = true;
```

Mounts are managed in `modules/system/storage.nix`:
```nix
fileSystems."/var/lib/immich" = {
  device = "BUZZ/immich";
  fsType = "zfs";
  options = [ "nofail" "X-systemd.automount" "x-systemd.mount-timeout=5s" ];
};

fileSystems."/share/Storage/WOODY/photos" = {
  device = "WOODY/photos";
  fsType = "zfs";
  options = [ "nofail" "X-systemd.automount" "x-systemd.mount-timeout=5s" ];
};
```

## Troubleshooting

Get the status of your pool and list their content
```bash
# Status
zpool status -v
# List Datasets
zfs list
```

When a pool was imported on another system, you often need to _force import_ it:
```bash
# List pools available for import
sudo zpool import
# Import the pool (replace poolname)
sudo zpool import <poolname>
# Or force import if it says already active
sudo zpool import -f <poolname>
```
 If for some reason the pool was mounted on a different location you have to restore the desired montpoint.
 For instance : 
 ```bash
 # Restore legacy mountpoint (handled by fstab)
 sudo zfs set mountpoint=legacy BUZZ
 ```
