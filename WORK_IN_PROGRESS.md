# Work In Progress: Immich Implementation

This document tracks the step-by-step implementation of Immich on the SKYLAB homeserver, including the networking infrastructure (Nginx + Cloudflare Tunnel).

## Current Status
- [/] Phase 1: Storage & Secrets Preparation (REVISED: Offloading /var/lib/immich)
- [x] Phase 2: Reverse Proxy (Nginx) (Configured for local network)
- [x] Phase 3: Immich Service Implementation (Module created and enabled)
- [ ] Phase 4: Verification & Polishing

---

## Phase 1: Storage & Secrets Preparation (Manual Steps Required)

The Nix configuration needs to be updated for the following:

### 1. External Library (Pictures Indexing)
- `@pictures` remains mounted at `/home/zipang/Pictures`.
- A bind mount exposes `/home/zipang/Pictures/Digicam` as `/media/immich`.
- **Action**: In the Immich UI, add `/media/immich` as an **External Library**.

### 2. Managed Data Offloading (Database, Thumbnails, ML)
To prevent the system partition from filling up, `/var/lib/immich` will be moved to a dedicated BTRFS subvolume on the `MEDIAS` drive.

**Manual Action Required**:
Before applying the next configuration update, create the subvolume on the `MEDIAS` drive:
```bash
# Assuming the MEDIAS drive is mounted at /mnt/medias or similar for maintenance
sudo btrfs subvolume create /mnt/medias/@immich
```

**Configuration Task**:
Update `modules/system/storage.nix` to include:
```nix
  fileSystems."/var/lib/immich" = {
    device = "/dev/disk/by-label/MEDIAS";
    fsType = "btrfs";
    options = [ "subvol=@immich" "compress=zstd" "noatime" ];
  };
```

### 3. Secrets Management
Add to `secrets/secrets.yaml` using `sops`:
* `immich/db_password`: A strong password for the PostgreSQL database (optional for local-only, but recommended).

---

## Detailed Plan

### Phase 1: Storage Migration (PENDING)
- [ ] Update `modules/system/storage.nix` with `/var/lib/immich` BTRFS subvolume.
- [ ] Verify `systemd.tmpfiles.rules` ownership for the new mount.

### Phase 2: Reverse Proxy
- [x] Configure `immich.skylab.local` in `modules/services/nginx.nix` (DONE).

### Phase 3: Immich Implementation
- [x] Complete `modules/services/immich.nix` with full options (DONE).
- [x] Add `services.immich.user` and `services.immich.group` (DONE).
- [x] Add `services.immich-public-proxy` to documentation (DONE).

### Phase 4: Verification
- [ ] Apply configuration via `sudo nixos-rebuild switch`.
- [ ] Verify `/var/lib/immich` is correctly mounted on the external drive.
- [ ] Test indexing performance.

---

## Technical Choices
- **Storage**: Offloading `/var/lib/immich` to BTRFS subvolume `@immich` on `MEDIAS` drive for capacity and snapshot support.
- **Compression**: `zstd` enabled on the subvolume to save space on thumbnails and database logs.
- **Proxy**: Nginx for local resolution.
