# Work In Progress: Immich Implementation (ZFS Migration)

This document tracks the step-by-step implementation of Immich on the SKYLAB homeserver, including the transition to ZFS storage for BUZZ (SSD) and WOODY (HDD Mirror).

## Current Status
- [/] Phase 1: Storage & Secrets Preparation (ZFS Migration)
- [x] Phase 2: Reverse Proxy (Nginx) (Configured for local network)
- [x] Phase 3: Immich Service Implementation (Module created and enabled)
- [ ] Phase 4: Verification & Polishing

---

## Phase 1: Storage & Secrets Preparation (ZFS Implementation)

The Nix configuration has been updated to support ZFS on SKYLAB (HostId: `8425e349`).

### 1. ZFS Pools Creation (Manual Action Required)
Run these commands on your workstation or the server to create the pools using the identified disk IDs:

**Pool BUZZ (4TB SSD)**:
```bash
sudo zpool create -f -o ashift=12 \
  -O compression=zstd -O acltype=posixacl -O xattr=sa -O relatime=on -O autotrim=on \
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
sudo zfs create BUZZ/immich
sudo zfs create WOODY/photos
```

### 3. Update Immich configuration
Update `modules/services/immich.nix` to point `mediaLocation` to `/share/Storage/WOODY/photos`.

---

## Detailed Plan

### Phase 1: Storage Migration (PENDING)
- [x] Update `modules/system/storage.nix` with ZFS pool mounts.
- [ ] Verify `systemd.tmpfiles.rules` ownership for the new mount.

### Phase 2: Reverse Proxy
- [x] Configure `immich.skylab.local` in `modules/services/nginx.nix` (DONE).

### Phase 3: Immich Implementation
- [x] Complete `modules/services/immich.nix` with full options (DONE).
- [x] Add `services.immich.user` and `services.immich.group` (DONE).
- [x] Add `services.immich-public-proxy` to documentation (DONE).

### Phase 4: Verification
- [ ] Apply configuration via `sudo nixos-rebuild switch`.
- [ ] Verify `/share/Storage/BUZZ` and `/share/Storage/WOODY` are correctly mounted.
- [ ] Test indexing performance.

---

## Technical Choices
- **Storage**: Offloading Immich media to ZFS mirror pool `WOODY` and database/cache to ZFS SSD pool `BUZZ`.
- **Compression**: `zstd` enabled on ZFS pools to save space on thumbnails and database logs.
- **Proxy**: Nginx for local resolution.
