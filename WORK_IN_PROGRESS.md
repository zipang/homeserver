# Work In Progress: SSL/TLS Certificate Setup (HTTPS)

This document tracks the implementation of a local Certificate Authority (CA) to enable HTTPS across all SKYLAB services using `.skylab.local` domains.

## Current Status
- [x] Phase 1: Storage & Immich Service (DONE)
- [x] Phase 2: System Preparation (mkcert added to core packages)
- [x] Phase 3: Nginx SSL Configuration (forceSSL enabled for Immich & Syncthing)
- [ ] Phase 4: Certificate Generation & Deployment (Pending Manual Action)

---

## Phase 4: Certificate Generation & Deployment (Manual)

Since we want to keep private keys out of Git, we are using a manual deployment to a persistent directory on SKYLAB.

### 1. Generate Root CA (On your Management Machine)
Run this once on the machine you use to manage the server:
```bash
mkcert -install
```

### 2. Create Wildcard Certificates
```bash
# In a temporary directory
mkcert "*.skylab.local" skylab.local 127.0.0.1 ::1
```

### 3. Copy to SKYLAB
Move the resulting `.pem` files to the server using `scp`:
```bash
scp _wildcard.skylab.local+3.pem skylab:/var/lib/secrets/certs/skylab.crt
scp _wildcard.skylab.local+3-key.pem skylab:/var/lib/secrets/certs/skylab.key
```
*Note: The `/var/lib/secrets/certs` directory is declaratively managed by NixOS with `nginx:nginx` ownership.*

### 4. Apply Configuration
Run `update-nix` on SKYLAB to apply the Nginx SSL configuration.

---

## Detailed Plan

### Phase 2: System Preparation (DONE)
- [x] Add `mkcert` to `environment.systemPackages` in `modules/system/core.nix`.
- [x] Add `systemd.tmpfiles.rules` to ensure `/var/lib/secrets/certs` existence and permissions.

### Phase 3: Nginx SSL Configuration (DONE)
- [x] Enable `forceSSL = true` for all virtual hosts.
- [x] Map `sslCertificate` and `sslCertificateKey` to `/var/lib/secrets/certs/skylab.crt` and `.key`.

### Phase 4: Verification
- [ ] Verify that `http://immich.skylab.local` automatically redirects to `https://`.
- [ ] Verify that browsers show a "Secure" green lock (after importing the Root CA).
- [ ] Verify Syncthing GUI remains accessible via HTTPS.

---

## Documentation
- [SSL Setup Guide](./docs/ssl-setup.md)
