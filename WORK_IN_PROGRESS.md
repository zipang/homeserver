# WORK IN PROGRESS

## 1. Public Domain & SSL (Cloudflare Migration)
We are moving DNS resolution to Cloudflare to enable the ACME DNS-01 challenge (for self-renewing SSL certificates).

### Tasks:
- [x] **Manual: Cloudflare Setup**
    1. **Add Site**: Log in to Cloudflare, click "Add a Site" on the dashboard, and enter your domain name.
    2. **Select Plan**: Choose the "Free" plan at the bottom and click "Continue".
    3. **Review DNS**: Cloudflare will scan existing records. Verify them and click "Continue".
    4. **Change Nameservers**: 
        - Log in to Namecheap.
        - Go to your Domain List > Manage > Nameservers.
        - Change from "Namecheap BasicDNS" to "Custom DNS".
        - Enter the two nameservers provided by Cloudflare (e.g., `ashley.ns.cloudflare.com`).
    5. **Wait for Propagation**: It can take from 10 minutes to 24 hours for the change to be active.
    6. **Create API Token**: 
        - Go to `My Profile > API Tokens > Create Token`.
        - Use "Edit zone DNS" template.
        - Under "Zone Resources", select `Specific zone` and choose your domain.
        - Copy the token immediately (it's only shown once).
- [ ] **Secrets**: Store the Cloudflare API Token in `secrets/secrets.yaml` (managed via sops).
    - Key: `acme/cloudflare_token`
    - Format: `CLOUDFLARE_DNS_API_TOKEN=your_token_here`
- [x] **NixOS**: Implement `modules/system/acme.nix` with the DNS-01 challenge provider.
- [x] **Nginx**: Update `modules/services/nginx.nix` to use the ACME certificate.

## Current State
- Domain points to `<PUBLIC_IP>`.
- Port 80/443 are closed (Router/Firewall).
- ACME DNS-01 is the chosen path for SSL.


---

## 2. Netbird - Self-hosted Zero Trust Mesh VPN

We are self-hosting the entire Netbird stack (Management, Signal, Relay, and Dashboard) to create a private mesh network. This allows secure, P2P access to services like Immich and Jellyfin without exposing them to the public internet.

### Architecture Decisions
- **Orchestration**: `virtualisation.oci-containers` (Docker) managed by NixOS.
- **Identity Provider**: Integrated with **PocketID** via OIDC.
- **Components**:
    - `netbird-management`: The core API and coordination service.
    - `netbird-signal`: Lightweight peer discovery service.
    - `netbird-dashboard`: Web UI for network management.
    - `coturn`: STUN/TURN relay for NAT traversal.
- **Database**: SQLite (built-in to Management for simplicity in homelab).
- **Networking**: Nginx reverse proxy for Dashboard and Management API.

### Implementation Plan

#### Phase 1: Documentation & Planning
- [x] **Create `/docs/netbird.md`**
    - Overview of the P2P mesh and OIDC flow.
    - Guide for client installation (Mobile/PC).
    - Instructions for accessing private services (Immich/Jellyfin).

#### Phase 2: Module Development
- [ ] **Create `/modules/services/netbird-server.nix`**
    - Define OCI containers for all components.
    - Configure OIDC environment variables for PocketID.
    - Setup data persistence in `/var/lib/netbird`.
    - Configure `coturn` for relay functionality.

- [ ] **Update Nginx Configuration**
    - Add virtual host for `netbird.${config.server.publicDomain}`.
    - Configure gRPC proxying for the Management API.

#### Phase 3: PocketID Integration
- [ ] **Configure OIDC Client in PocketID**
    - Name: "Netbird"
    - Redirect URI: `https://netbird.<domain>/auth/callback`
    - Get Client ID and Secret.

#### Phase 4: Testing & Deployment
- [ ] Deploy to SKYLAB.
- [ ] Test `netbird up` from a remote device.
- [ ] Verify P2P connection (via `netbird status`).

### Current State
- ✅ Plan defined in `WORK_IN_PROGRESS.md`.
- ✅ Documentation draft created.
