# ZFS Storage (BUZZ & WOODY)

This document describes the ZFS configuration used for high-performance and redundant storage on the SKYLAB homelab server.

## Overview
We use ZFS to manage external drives connected via USB-C. This provides superior data integrity, compression, and logical volume management compared to traditional partitions or BTRFS subvolumes.

*   **Pool `BUZZ`**: Single-disk pool on a 4TB SSD. Optimized for high-speed access (Immich database, active workspace).
*   **Pool `WOODY`**: Mirrored pool (RAID1) on two 12TB HDDs. Optimized for long-term redundant storage (Photos, Archives).

## Configuration Reference
*   [NixOS ZFS Options](https://search.nixos.org/options?query=boot.zfs)
*   [ZFS on NixOS Wiki](https://nixos.wiki/wiki/ZFS)

## ZFS Installation on Fedora

Because ZFS is not included into latest Fedora we have to use openzfs.

Instructions found on the [OpenZFS documentation](https://openzfs.github.io/openzfs-docs/Getting%20Started/Fedora/index.html)

```
# Add ZFS repo:
dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-0$(rpm --eval "%{dist}").noarch.rpm

# Install kernel headers:
sudo dnf install -y kernel-devel-$(uname -r | awk -F'-' '{print $1}')

# Install ZFS packages:
sudo dnf install zfs

# Load kernel module:
sudo modprobe zfs
```

## Pool Creation (Manual)

To ensure stability across reboots, pools are created using unique disk IDs from `/dev/disk/by-id/`.

### BUZZ (SSD)
```bash
sudo zpool create -f -o ashift=12 \
  -O compression=zstd \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -O autotrim=on \
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
Instead of directories, we use ZFS datasets for isolation:
*   `BUZZ/immich`: Immich database and cache.
*   `WOODY/photos`: Master photo library.

```bash
sudo zfs create BUZZ/immich
sudo zfs create WOODY/photos
```

## NixOS Integration

ZFS support is enabled in `modules/system/boot.nix`:
```nix
boot.supportedFilesystems = [ "zfs" ];
networking.hostId = "8425e349"; # Required for ZFS
```

Mounts are managed in `modules/system/storage.nix`:
```nix
fileSystems."/share/External/BUZZ" = {
  device = "BUZZ";
  fsType = "zfs";
  options = [ "nofail" "X-systemd.automount" ];
};
```

## Troubleshooting
*   **Import failure**: If the pool won't import due to a hostId mismatch: `sudo zpool import -f <pool-name>`.
*   **Status**: `zpool status -v`
*   **List Datasets**: `zfs list`
