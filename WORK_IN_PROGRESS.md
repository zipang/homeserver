# Deployment Plan: zrok SSO & Public Access on SKYLAB

We are transitioning from Authelia + Cloudflare Tunnels to a self-hosted `zrok` (OpenZiti) instance to provide secure public access with OAuth (Google/GitHub) authentication.

## Goals
- Self-host a full `zrok` instance (controller, router, and public frontend).
- Replace Cloudflare Tunnels for public access.
- Replace Authelia with `zrok`'s built-in OAuth support for SSO.
- Securely expose Immich and Nextcloud.

## Phase 1: Research & Preparation
- [ ] Verify `zrok-instance` Docker configuration and OAuth requirements.
- [ ] Identify necessary network ports and DNS requirements (zrok needs a wildcard DNS or specific subdomains).
- [ ] Prepare Google/GitHub OAuth application credentials.

## Phase 2: zrok Infrastructure Implementation
- [ ] Create `modules/services/zrok.nix` using `virtualisation.oci-containers`.
- [ ] Set up `sops-nix` secrets for zrok admin and OAuth credentials.
- [ ] Configure systemd services to manage the zrok lifecycle.

## Phase 3: Service Migration
- [ ] Configure `zrok` to share Nextcloud and Immich.
- [ ] Update Nginx configuration if necessary (or bypass it if zrok talks directly to services).
- [ ] Test public access and OAuth flow.

## Phase 4: Cleanup
- [ ] Disable and remove `modules/services/authelia.nix`.
- [ ] Disable and remove `modules/services/cloudflared.nix`.
- [ ] Update documentation (`docs/zrok.md`).

## Current Status
- [x] Implemented `zrok.nix` infrastructure with bootstrap logic and static homepage.
- [x] Created `scripts/generate-zrok-secrets.sh` for manual secret management.
- [ ] Deploying to SKYLAB and verifying root domain share.

## Deployment Steps (on SKYLAB)

1. **Pull and Apply Configuration**:
   ```bash
   update-nix
   ```

2. **Initialize Secrets**:
   ```bash
   sudo ./scripts/generate-zrok-secrets.sh
   # Edit /var/lib/secrets/zrok/frontend.env to add Google OAuth credentials
   ```

3. **Verify Configuration Generation**:
   Check if YAML files are generated correctly:
   ```bash
   systemctl status zrok-init.service
   ls -l /var/lib/zrok-controller/config.yml
   ```

4. **Monitor Infrastructure**:
   ```bash
   journalctl -u docker-ziti-controller.service -f
   journalctl -u docker-zrok-controller.service -f
   ```

5. **Expose Homepage**:
   Once the controller is healthy, we will need to perform the initial zrok invite and share (I will provide commands for this in the next session).
