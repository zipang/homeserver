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

## 2. Pocketid - OIDC Provider for Passwordless Authentication

We are integrating Pocketid as a centralized OIDC provider to enable passwordless authentication (via passkeys) for home server services like Immich. Pocketid will manage users who have authorized access to these services.

### Architecture Decisions
- **Database**: PostgreSQL (shared with Immich and future services)
- **User Management**: Direct management in Pocketid (admin-only signups - no public registration)
- **Secrets Storage**: Plain environment file at `/var/lib/secrets/pocketid.env` (not sops-encrypted)
- **Access**: Nginx reverse proxy on `pocketid.skylab.local` with SSL/TLS
- **Service Port**: `127.0.0.1:1411` (localhost only, behind Nginx)

### Implementation Plan

#### Phase 1: Module Creation
- [x] **Create `/modules/services/pocketid.nix`**
    - Enable `services.pocketid` with PostgreSQL backend
    - Load environment variables from `/var/lib/secrets/pocketid.env`
    - Configure systemd service with proper dependencies on PostgreSQL
    - Set service user permissions to read secrets file
    - Configure logging and error handling

- [x] **Update PostgreSQL Configuration** (`modules/services/postgresql.nix`)
    - Add Pocketid database user: `pocketid`
    - Create database: `pocketid`
    - Grant proper privileges to the pocketid user
    - Ensure PostgreSQL starts before Pocketid

- [x] **Update Nginx Configuration** (`modules/services/nginx.nix`)
    - Add virtual host for `pocketid.${config.server.privateDomain}`
    - Configure SSL with self-signed certs (`/var/lib/secrets/certs/skylab.crt|key`)
    - **CRITICAL**: Add Nginx buffer settings for SvelteKit large headers:
      ```
      proxy_busy_buffers_size 512k;
      proxy_buffers 4 512k;
      proxy_buffer_size 256k;
      ```
    - Proxy traffic to `http://127.0.0.1:1411`
    - Set `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`

#### Phase 2: Configuration & Secrets
- [x] **Create Setup Script** (`scripts/generate-pocketid-secrets`)
    - Automated encryption key generation
    - Interactive prompts for database password and configuration
    - Automatic .env file creation with proper permissions (0600)
    - User/group ownership detection with fallback
    
- [x] **Update Host Configuration** (`hosts/SKYLAB/configuration.nix`)
    - Add import: `../../modules/services/pocketid.nix`

#### Phase 3: Documentation
- [x] **Create `/docs/pocketid.md`** following syncthing.md structure:
    - **Overview**: Purpose and module path
    - **Configuration Reference**: Link to NixOS options search (25.11 channel)
    - **Full Configuration Template**: Complete Nix configuration example
    - **Operational Guides**: 
      - Accessing admin interface at `https://pocketid.skylab.local/setup`
      - Creating admin account (first time setup)
      - Managing users via UI
      - Configuring OIDC clients for other services
    - **Headless Operations & Troubleshooting**:
      - `journalctl -u pocket-id.service -f` (logs)
      - `systemctl status pocket-id.service` (status check)
      - Database connection troubleshooting
      - WebAuthn passkey setup process

- [x] **Update `/README.md`**
    - Add link to Pocketid documentation in the service list
    - Add link to setup instructions
    - Note about OIDC integration with Immich

#### Phase 4: Testing & Validation (Pending on SKYLAB)
- [ ] Apply NixOS configuration: `sudo nixos-rebuild switch --flake .#SKYLAB`
- [ ] Create `/var/lib/secrets/pocketid.env` with proper encryption key (see pocketid-setup.md)
- [ ] Verify `pocket-id` service starts successfully: `systemctl status pocket-id.service`
- [ ] Check PostgreSQL connection works (no errors in logs)
- [ ] Access admin setup at `https://pocketid.skylab.local/setup`
- [ ] Create test admin account with passkey
- [ ] Verify journalctl shows successful initialization
- [ ] Test that Pocketid can be accessed from LAN only (privacy)

### Key Technical Notes

**Security Considerations:**
- Encryption key is stored in plain text at `/var/lib/secrets/pocketid.env`
- File permissions will be `0600` (readable only by root and pocketid user)
- HTTPS is mandatory for Pocketid (WebAuthn requires secure context)
- User signup is disabled to prevent unauthorized access

**NixOS Integration:**
- Pocketid package is available in `nixos-25.11` (confirmed via docs)
- Service is automatically created as `pocket-id.service`
- PostgreSQL must start before Pocketid (systemd dependency)

**Nginx Configuration:**
- SvelteKit generates large headers, requires buffer size increase
- Must be behind reverse proxy with `TRUST_PROXY=true`
- Self-signed certificate is sufficient for local network

**Database:**
- PostgreSQL connection uses Unix socket: `postgresql://pocketid:PASSWORD@localhost/pocketid`
- No external database access needed
- Database connection pool handled by Pocketid

### Potential Issues & Solutions

| Issue | Solution |
|-------|----------|
| Nginx 431 "Request Header Fields Too Large" | Already addressed: buffer settings in plan |
| PostgreSQL connection refused | Ensure PostgreSQL service is enabled and running first |
| Passkeys not working in browser | HTTPS is mandatory, check certificate validity |
| Admin setup page not accessible | Verify Nginx reverse proxy is configured, check firewall |
| Pocketid logs show encryption errors | Check `ENCRYPTION_KEY` is correctly set in `.env` file |

### Current State
- ✅ Pocketid module implemented with corrected `settings` attribute
- ✅ PostgreSQL user/database configured
- ✅ Nginx reverse proxy configured with SvelteKit buffer settings
- ✅ Comprehensive documentation created
- ✅ Automated secrets generation script implemented
- ✅ All changes committed and pushed to master branch

### Implementation Notes

**Fixes Applied:**
1. **Fix 1**: Used non-existent `services.pocket-id.database` option
   - Corrected to use `services.pocket-id.settings` for environment variables
   
2. **Fix 2**: Initial attempt used `systemd.services.pocket-id.environmentFiles` (incorrect)
   - Corrected to use `services.pocket-id.environmentFile` (service-level option)
   - Secrets now properly loaded from `/var/lib/secrets/pocketid.env`
   
3. **Fix 3**: Settings used string types instead of proper NixOS types
   - `PORT = 1411` (integer, not string)
   - `TRUST_PROXY = true` (boolean, not string)
   
4. **User Permissions**: Pocket-id user added to postgres group for Unix socket access

**Final Module Architecture:**
```nix
services.pocket-id = {
  enable = true;
  environmentFile = "/var/lib/secrets/pocketid.env";  # Secrets file
  settings = {
    HOST = "127.0.0.1";
    PORT = 1411;                                       # Integer, not string
    TRUST_PROXY = true;                               # Boolean, not string
  };
};
```

### Ready for Deployment
The Pocketid implementation is complete and ready to be deployed to SKYLAB. Run the following on the server:

```bash
# 1. Apply the NixOS configuration
sudo nixos-rebuild switch --flake .#SKYLAB

# 2. Generate the secrets file (interactive)
sudo ~/scripts/generate-pocketid-secrets

# 3. Set the PostgreSQL password
sudo -u postgres psql -c "ALTER USER pocketid WITH PASSWORD '<password-from-script>';"

# 4. Check service status
sudo systemctl status pocket-id.service

# 5. Access the admin interface
# Navigate to: https://pocketid.skylab.local/setup
```
