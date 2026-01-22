# Work In Progress: Immich Implementation

This document tracks the step-by-step implementation of Immich on the SKYLAB homeserver, including the networking infrastructure (Nginx + Cloudflare Tunnel).

## Current Status
- [x] Phase 1: Storage & Secrets Preparation (Configuration updated)
- [x] Phase 2: Reverse Proxy (Nginx) & Cloudflare Tunnel (Modules created)
- [x] Phase 3: Immich Service Implementation (Module created)
- [ ] Phase 4: Verification & Polishing

---

## Phase 1: Storage & Secrets Preparation (Manual Steps Required)

The Nix configuration has been updated to expect the following:

### 1. BTRFS Subvolume & Import Path
We have configured a specific exposure for Immich to isolate it from the rest of your `@pictures` subvolume:
1.  `@pictures` remains mounted at `/home/zipang/Pictures`.
2.  A bind mount exposes `/home/zipang/Pictures/Digicam` as `/media/immich`.
3.  This bypasses Systemd's `ProtectHome` and isolates Immich to only your personal photos.
4.  Immich's managed data (thumbnails, DB, etc.) will stay in the default `/var/lib/immich` on the system drive.

**Action**: In the Immich UI, add `/media/immich` as an **External Library**.

### 2. Secrets Management
You need to add the following secrets to your `secrets/secrets.yaml` using `sops`:

*   `immich/db_password`: A strong password for the PostgreSQL database.
*   `cloudflared/tunnel_id`: The UUID of your Cloudflare tunnels
*   `cloudflared/credentials`: The JSON content of your Cloudflare tunnel credentials file.

Run: `sops secrets/secrets.yaml` and add these keys.

---

## Detailed Plan

### Phase 1: Storage & Secrets Preparation
- [ ] Define storage path for Immich data (e.g., `/media/immich`).
- [ ] Add `immich-db-password` to `secrets/secrets.yaml` (via sops).
- [ ] Add Cloudflare Tunnel credentials to `secrets/secrets.yaml`.

### Phase 2: Reverse Proxy & Tunnel
- [ ] Create `modules/services/nginx.nix` as a lightweight central proxy.
- [ ] Create `modules/services/cloudflared.nix` for secure external access.
- [ ] Configure DNS-01 ACME challenge for SSL (optional if using Cloudflare Tunnel edge SSL).

### Phase 3: Immich Implementation
- [ ] Create `modules/services/immich.nix` using the official NixOS module.
- [ ] Configure PostgreSQL with `pgvecto-rs` (managed by module).
- [ ] Configure Redis (managed by module).
- [ ] Link Immich to the Nginx virtual host.

### Phase 4: Verification
- [ ] Apply configuration via `sudo nixos-rebuild switch`.
- [ ] Test large file uploads (client_max_body_size).
- [ ] Verify external access via Cloudflare Tunnel.

---

## Technical Choices
- **Proxy**: Nginx (Lightest full-featured proxy for NixOS).
- **External Access**: Cloudflare Tunnel (No open ports, secure outbound connection).
- **Storage**: BTRFS subvolume on `MEDIAS` drive for easy snapshots and capacity management.
- **Secrets Management**: `sops-nix` with `age` keys.
