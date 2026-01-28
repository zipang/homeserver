# Work In Progress: Authelia SSO Implementation

This document tracks the setup of Authelia as a central Identity Provider (IdP) for SKYLAB services, using Google OAuth for external access and providing a seamless bypass for local network traffic.

## Current Status
- [x] Phase 1: SSL/TLS Infrastructure (DONE)
- [x] Phase 2: Reusable Secret Generator (Implemented in Bun/TS)
- [x] Phase 3: Authelia Service Implementation (Implemented with PostgreSQL & Redis)
- [x] Phase 4: Nginx Integration & Auth Middleware (Implemented for Syncthing & Immich)
- [ ] Phase 5: Service Migration (Immich OIDC Configuration)
- [ ] Phase 6: External Access (Cloudflare Tunnel Updates)

---

## Phase 2: Secret Management

We implemented a generic secret generator that can be reused for any service.

*   **Script**: `scripts/generate-secrets.ts` (Bun/TypeScript).
*   **Template**: `secrets/authelia`.
*   **Usage**: `bun scripts/generate-secrets.ts --template <template> --sshPublicKey <path> --outputDir <path>`.
*   **Output**: `<outputDir>/<template>.env` (Encrypted with `sops`).

## Phase 3: Authelia Service Implementation

*   **Backend**: PostgreSQL (Declarative setup in `authelia.nix`).
*   **Sessions**: Redis.
*   **Access Control**:
    *   `*.skylab.local` + `192.168.1.0/24` -> `bypass`.
    *   Otherwise -> `one_factor` (Google SSO).

## Phase 4: Nginx Integration

*   Vhost: `auth.skylab.local`.
*   Middleware: `auth_request` gating for non-OIDC services.

---

## Documentation
- [SSL Setup Guide](./docs/ssl-setup.md)
- [Authelia SSO Guide](./docs/authelia.md)
