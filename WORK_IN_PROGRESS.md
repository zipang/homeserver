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
- [x] Successfully applied configuration on SKYLAB.
- [ ] Finalizing zrok account setup and public shares.

## Deployment Steps (on SKYLAB)

Please refer to the detailed **First-Time Setup** guide in [docs/zrok.md](./docs/zrok.md) to:
1. Create your user account.
2. Configure the local CLI.
3. Enable your environment.
4. Expose the homepage.

## Verification
Navigate to `https://skylab.quest` to see your "SKYLAB HOMELAB" page.
