# Work In Progress: Immich Implementation (ZFS Migration)

This document tracks the step-by-step implementation of Immich on the SKYLAB homeserver, including the transition to ZFS storage for BUZZ (SSD) and WOODY (HDD Mirror).

## Current Status
- [x] Phase 1: Storage & Secrets Preparation (ZFS Migration)
- [x] Phase 2: Reverse Proxy (Nginx) (Configured for local network)
- [x] Phase 3: Immich Service Implementation (Module created and enabled)
- [/] Phase 4: Network Sharing & Verification

---

## Phase 1: Storage & Secrets Preparation (ZFS Implementation)

The Nix configuration has been updated to support ZFS on SKYLAB (HostId: `8425e349`).

### 1. ZFS Pools Creation (Manual Action Required)
Run these commands on your workstation or the server to create the pools using the identified disk IDs:

**Pool BUZZ (4TB SSD)**:
```bash
sudo zpool create -f -o ashift=12 -o autotrim=on \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O relatime=on \
  BUZZ usb-Realtek_RTL9210B-CG_012345678944-0:0
```

**Pool WOODY (12TB HDD Mirror)**:
```bash
sudo zpool create -f -o ashift=12 \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O relatime=on \
  WOODY mirror \
  usb-ASMT_ASM1352R-PM_AAAABBBB0003-0:0 \
  usb-ASMT_ASM1352R-PM_AAAABBBB0003-0:1
```

### 2. Create Datasets for Immich
```bash
# Set pools to legacy mode to allow NixOS to manage mounts
sudo zfs set mountpoint=legacy BUZZ
sudo zfs set mountpoint=legacy WOODY

# Create datasets and set to legacy mode
sudo zfs create BUZZ/immich
sudo zfs set mountpoint=legacy BUZZ/immich

sudo zfs create WOODY/photos
sudo zfs set mountpoint=legacy WOODY/photos
```

### 3. Update Immich configuration
Update `modules/services/immich.nix` to point `mediaLocation` to `/share/Storage/WOODY/photos`.
Database and thumbnails will be stored in `/var/lib/immich` (mounted on `BUZZ/immich`).

---

## Detailed Plan

### Phase 1: Storage Migration (DONE)
- [x] Update `modules/system/storage.nix` with ZFS pool mounts.
- [x] Verify `systemd.tmpfiles.rules` ownership for the new mount.

### Phase 2: Reverse Proxy (DONE)
- [x] Configure `immich.skylab.local` in `modules/services/nginx.nix` (DONE).

### Phase 3: Immich Implementation (READY)
- [x] Complete `modules/services/immich.nix` with full options (DONE).
- [x] Add `services.immich.user` and `services.immich.group` (DONE).
- [x] Add `services.immich-public-proxy` to documentation (DONE).

### Phase 4: Network Sharing & Verification
- [x] Export `/share/Storage` via NFS and Samba.
- [ ] Apply configuration via `sudo nixos-rebuild switch`.
- [ ] Verify `/share/Storage/BUZZ` and `/share/Storage/WOODY` are correctly mounted.
- [ ] Test indexing performance with Immich.
- [ ] Verify NFS and Samba access to the new pools.

---

## Technical Choices
- **Storage**: Offloading Immich media to ZFS mirror pool `WOODY` and database/cache to ZFS SSD pool `BUZZ`.
- **Mount Strategy**: Using ZFS `legacy` mountpoints managed by NixOS `fileSystems` with `nofail`, `X-systemd.automount`, and a shortened `x-systemd.mount-timeout=5s` for maximum boot resilience.
- **Networking**: Exporting `/share/Storage` via NFS and Samba for easy access to photos and backups.
- **Compression**: `zstd` enabled on ZFS pools to save space on thumbnails and database logs.
- **Proxy**: Nginx for local resolution.
