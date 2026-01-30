# Deployment Plan: Nextcloud on SKYLAB

Nextcloud has been successfully implemented in the configuration.

## Completed Tasks
- [x] Phase 1: Storage & Database Preparation
- [x] Phase 2: Secret Generator
- [x] Phase 3: Nextcloud Service Module
- [x] Phase 4: Nginx & Authelia Integration
- [x] Phase 5: System Integration
- [x] Phase 6: Refactoring (Global PostgreSQL & Redis Modules)
- [x] Phase 7: Immich Service Migration
- [x] Phase 8: Documentation

## Completed Tasks
- [x] Created `modules/services/postgresql.nix` and `modules/services/redis.nix`.
- [x] Refactored `authelia.nix`, `nextcloud.nix`, and `immich.nix` to use these shared modules.
- [x] Updated permissions for `authelia-main`, `nextcloud`, and `immich` users to access Unix sockets.
- [x] Created registries in `docs/postgresql.md` and `docs/redis.md`.
- [x] Enriched `docs/nextcloud.md` with detailed descriptions and allowed values.

## Next Steps for User (on SKYLAB)

1. **Pull and Apply Configuration**:
   ```bash
   update-nix
   ```

2. **Generate Secrets**:
   ```bash
   sudo ./scripts/generate-nextcloud-secrets.sh
   ```

3. **Set Database Password**:
   ```bash
   sudo -u postgres psql -c "ALTER USER nextcloud WITH PASSWORD '$(sudo cat /var/lib/secrets/nextcloud/db_password)';"
   ```

4. **Verify Service**:
   Check logs for the setup process:
   ```bash
   journalctl -u nextcloud-setup.service -f
   ```

5. **Access Nextcloud**:
   Navigate to `https://nextcloud.skylab.local` and log in with the `admin` account (password in `/var/lib/secrets/nextcloud/admin_password`).
