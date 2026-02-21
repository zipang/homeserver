# Pocketid - OIDC Provider for Passwordless Authentication

Pocketid is a lightweight, self-hosted OIDC provider that enables passwordless authentication using passkeys (WebAuthn). It allows centralized user management for home server services like Immich while maintaining strong security through passkey-based authentication.

The service is configured in `modules/services/pocketid.nix`.

## Overview

**Purpose**: Pocketid serves as an identity provider for your home server, allowing services like Immich to delegate user authentication to a centralized system. Instead of managing passwords, users authenticate using passkeys (supported by Yubikeys, Windows Hello, face recognition, etc.).

**Key Features**:
- Passwordless authentication via passkeys (WebAuthn)
- OIDC provider for service integration
- User and group management
- Audit logging
- Admin dashboard at `https://pocketid.skylab.local/setup`

**Database**: PostgreSQL (shared with Immich, Nextcloud, and other services)

**Access**: Via Nginx reverse proxy on `pocketid.skylab.local` (local network only)

## Configuration Reference

The complete list of available options for the `services.pocket-id` module can be found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.pocket-id) when choosing the 25.11 channel.

## Full Configuration Template

The basic Pocketid configuration in `modules/services/pocketid.nix`:

```nix
{ config, pkgs, ... }:

{
  services.pocket-id = {
    # Whether to enable the Pocket ID OIDC provider service.
    enable = true;
  
    # Explicitly set user and group to avoid hyphen issues in PostgreSQL
    user = "pocketid";
    group = "pocketid";
  
    # Use a data directory without hyphens to avoid permission confusion
    # NixOS will create this directory with the right permissions
    dataDir = "/var/lib/pocketid";
  
    # Sensitive data (ENCRYPTION_KEY) is loaded from this file.
    # It must contain: ENCRYPTION_KEY=...
    environmentFile = "/var/lib/secrets/pocketid.env";
  
    # Public configuration is set in settings
    # For version 1.15.0, these are the correct variables.
    settings = {
      APP_URL = "https://pocketid.${config.server.privateDomain}";
      TRUST_PROXY = true;
  
      # Database configuration for v1.15.0+ and v2.x
      DB_PROVIDER = "postgres";
      DB_CONNECTION_STRING = "host=/run/postgresql user=pocketid database=pocketid";
  
      # Compatibility for older v1.x (though 1.15.0 should use the above)
      POSTGRES_CONNECTION_STRING = "host=/run/postgresql user=pocketid database=pocketid";
  
      # Where to store JWKs (database is recommended for stateless/easier backups)
      KEYS_STORAGE = "database";
    };
  };

}
```

## Environment Variables Configuration

Pocketid is configured via environment variables stored in `/var/lib/secrets/pocketid.env`. The following are the essential variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `APP_URL` | `https://pocketid.skylab.local` | The URL where Pocketid is publicly accessible |
| `ENCRYPTION_KEY` | Generated 32-byte base64 string | Key for encrypting sensitive data (generated via `openssl rand -base64 32`) |
| `TRUST_PROXY` | `true` | Set to true because Pocketid is behind Nginx reverse proxy |
| `PORT` | `1411` | Internal port for Pocketid service |
| `HOST` | `127.0.0.1` | Internal listening address (localhost only) |
| `DB_CONNECTION_STRING` | `postgresql://pocketid:PASSWORD@localhost/pocketid` | PostgreSQL connection string |
| `ALLOW_USER_SIGNUPS` | `disabled` | Disable public signup (admin-only user creation) |
| `UI_CONFIG_DISABLED` | `false` | Allow UI-based configuration |
| `LOG_LEVEL` | `info` | Logging verbosity (debug, info, warn, error) |
| `APP_NAME` | `SKYLAB Pocketid` | Custom application name shown in UI |
| `SESSION_DURATION` | `60` | Session timeout in minutes |

## Operational Guides

### Initial Setup - Creating the Admin Account

On first deployment, the admin setup page is available to anyone. Follow these steps:

1. **Access Setup Page**:
   ```
   https://pocketid.skylab.local/setup
   ```

2. **Create Admin Account**:
   - Choose a username (will be used in admin interface)
   - Register a passkey using your browser's passkey manager
   - Complete the setup

3. **First Login**:
   - Visit `https://pocketid.skylab.local`
   - Sign in with your newly created passkey
   - Access admin settings via the top-right menu

4. **Reset Setup Page** (if needed):
   - If you miss the initial setup, the setup page can be reset by modifying database directly or contacting Pocketid support
   - This is a security feature to prevent unauthorized account creation

### Managing Users

Users can be created and managed through the Pocketid admin interface:

1. **Login** as admin at `https://pocketid.skylab.local`
2. **Navigate** to "Users" or "Settings > Users"
3. **Create New User**:
   - Click "Add User" or "Invite User"
   - Enter username and email
   - Send invite link to user (via email)
   - User receives link and registers their passkey

4. **Create Groups** (optional):
   - Groups can be used to manage permissions for multiple users
   - Assign users to groups for easier management in OIDC integrations

### Configuring OIDC Clients

Pocketid acts as an OIDC provider for services like Immich. To add a service:

1. **Login** as admin
2. **Navigate** to "OIDC Clients" or "Applications"
3. **Create New Client**:
   - Enter application name (e.g., "Immich")
   - Set redirect URI (e.g., `https://immich.skylab.local/auth/callback`)
   - Copy the Client ID and Client Secret
   - Configure the service with these credentials

4. **Service-Side Configuration**:
   - Configure Immich (or other service) to use Pocketid as OIDC provider
   - Set OIDC endpoint: `https://pocketid.skylab.local`
   - Paste Client ID and Secret

### Viewing Audit Logs

Pocketid maintains detailed audit logs of all authentication and user management events:

1. **Login** as admin
2. **Navigate** to "Audit Log" or "Settings > Audit"
3. **View Log Entries**:
   - Filter by event type, user, date range
   - Check for suspicious login attempts or unauthorized access
   - GeoIP location data available if MaxMind license key is configured

### Passkey Management

For users managing their own passkeys:

1. **Login** to Pocketid
2. **Navigate** to "Settings > Account"
3. **View Passkeys**:
   - See registered devices (Yubikey, iPhone, Windows Hello, etc.)
   - Device type and last used timestamp
   - Add additional passkeys for backup access
   - Remove old devices

## Headless Operations & Troubleshooting

### Checking Service Status

```bash
# Check if pocket-id service is running
sudo systemctl status pocket-id

# Restart the service
sudo systemctl restart pocket-id

# Stop the service
sudo systemctl stop pocket-id

# Start the service
sudo systemctl start pocket-id
```

### Viewing Logs

```bash
# View recent logs (last 50 lines)
sudo journalctl -u pocket-id -n 50

# Follow logs in real-time
sudo journalctl -u pocket-id -f

# View logs with timestamps and detailed output
sudo journalctl -u pocket-id --no-pager -o short-precise

# Filter logs for errors only
sudo journalctl -u pocket-id -p err

# View logs for the last hour
sudo journalctl -u pocket-id --since "1 hour ago"
```

### Database Connection Testing

```bash
# Test database connectivity as the pocket-id user
sudo -u pocket-id psql postgresql://pocket-id?host=/run/postgresql -c "SELECT version();"

# List all tables in the pocketid database
sudo -u pocket-id psql postgresql://pocket-id?host=/run/postgresql -c "\dt"

# Check database size
sudo -u pocket-id psql postgresql://pocket-id?host=/run/postgresql -c "SELECT pg_size_pretty(pg_database_size('pocketid'));"
```

### Verifying Secrets File

```bash
# Check that the secrets file exists and has correct permissions
ls -la /var/lib/secrets/pocketid.env
# Should show: -rw------- 1 pocket-id pocket-id

# Verify encryption key is readable (as pocket-id user)
sudo -u pocket-id cat /var/lib/secrets/pocketid.env | grep ENCRYPTION_KEY

# Check all configuration variables
sudo cat /var/lib/secrets/pocketid.env
```

### Testing Nginx Reverse Proxy

```bash
# Test Nginx configuration for syntax errors
sudo nginx -t

# View Nginx error logs
sudo journalctl -u nginx -f

# Test connectivity to Pocketid backend
curl -v http://127.0.0.1:1411/health

# Test through reverse proxy (will fail with SSL if not trusted)
curl -k https://pocketid.skylab.local
```

### Troubleshooting Common Issues

#### Service Fails to Start

```bash
# Check detailed error messages
sudo journalctl -u pocket-id --no-pager

# Verify environment file is readable
ls -la /var/lib/secrets/pocketid.env
sudo -u pocket-id cat /var/lib/secrets/pocketid.env
```

**Common causes:**
- Permission denied reading `.env` file
- Invalid encryption key (not valid base64)
- PostgreSQL not running or database doesn't exist
- Port 1411 already in use

#### Cannot Access Admin Interface

```bash
# Test if service is listening
sudo netstat -tlnp | grep 1411

# Test reverse proxy connection
curl -v http://127.0.0.1:1411/

# Check Nginx configuration
sudo nginx -T | grep -A 20 pocketid
```

**Common causes:**
- Nginx not running or not configured correctly
- SSL certificate missing or invalid
- Service not listening on expected port
- Firewall blocking access

#### Database Connection Errors

```bash
# Verify PostgreSQL is running
sudo systemctl status postgresql

# Check if pocketid database and user exist
sudo -u postgres psql -l | grep pocketid
sudo -u postgres psql -c "\du" | grep pocketid

# Manually test connection
sudo -u pocket-id psql postgresql://pocketid:PASSWORD@localhost/pocketid
```

**Common causes:**
- PostgreSQL service not running
- Database or user not created
- Incorrect password in connection string
- PostgreSQL not listening on localhost

#### Encryption Key Validation Errors

If you see errors related to encryption keys:

```bash
# Verify the key is valid base64 (should output 32)
echo "YOUR_ENCRYPTION_KEY" | base64 -d | wc -c

# Check that key has no trailing whitespace
grep ENCRYPTION_KEY /var/lib/secrets/pocketid.env | od -c | tail
```

If needed, rotate the encryption key:
```bash
sudo systemctl stop pocket-id
# Generate new key
NEW_KEY=$(openssl rand -base64 32)
# Update the file
sudo nano /var/lib/secrets/pocketid.env
# Run encryption key rotation command (if supported by your Pocketid version)
sudo systemctl start pocket-id
```

### Performance Monitoring

```bash
# Monitor service memory and CPU usage
sudo systemctl status pocket-id
ps aux | grep pocket-id

# Check database query performance
sudo -u pocket-id psql postgresql://pocketid:PASSWORD@localhost/pocketid << 'EOF'
SELECT now();
SELECT COUNT(*) FROM users;
EOF

# Monitor Nginx request rates for Pocketid
sudo journalctl -u nginx -f | grep pocketid
```

### Backup and Recovery

```bash
# Backup Pocketid database
sudo -u postgres pg_dump pocketid > /tmp/pocketid-backup.sql

# Backup secrets file
sudo cp /var/lib/secrets/pocketid.env /tmp/pocketid.env.backup

# Restore from backup (if needed)
sudo -u postgres dropdb pocketid
sudo -u postgres createdb -O pocketid pocketid
sudo -u postgres psql pocketid < /tmp/pocketid-backup.sql
```

## Integration with Immich

To use Pocketid for Immich authentication:

1. **Create OIDC Client** in Pocketid (see "Configuring OIDC Clients" above)
2. **Configure Immich** with Pocketid:
   - OIDC Server: `https://pocketid.skylab.local`
   - Client ID: (from Pocketid)
   - Client Secret: (from Pocketid)
   - Redirect URI: `https://immich.skylab.local/auth/callback`
3. **Enable OIDC Login** in Immich settings
4. **Test** by logging out and signing in with passkey

## Security Considerations

- **HTTPS Required**: Pocketid requires HTTPS for WebAuthn to function (passkeys won't work over HTTP)
- **Local Network Only**: Access limited to LAN via self-signed certificates
- **Encryption Key**: Stored in plain text at `/var/lib/secrets/pocketid.env` with restricted permissions (mode 0600)
- **Passkey Security**: Users authenticate with cryptographic keys, not passwords
- **Audit Logging**: All authentication and management events are logged
- **Session Timeout**: Configurable session duration (default 60 minutes)

## Setup Instructions

To initialize Pocketid after deploying to SKYLAB, use the secrets generation script:

```bash
# On SKYLAB server, run with sudo:
sudo ~/scripts/generate-pocketid-secrets

# This script will:
# 1. Generate a secure encryption key
# 2. Prompt for database password and configuration
# 3. Create /var/lib/secrets/pocketid.env with all necessary settings
# 4. Set proper file permissions for the pocket-id user
```

Then update the PostgreSQL user password:

```bash
sudo -u postgres psql -c "ALTER USER pocketid WITH PASSWORD '<password-from-script>';"
```

## Useful Links

- [Pocketid Official Documentation](https://pocket-id.org)
- [Pocketid Demo Instance](https://demo.pocket-id.org)
- [Pocketid GitHub Repository](https://github.com/pocket-id/pocket-id)
- [Passkeys Overview](https://www.passkeys.io/)

## Related Documentation

- [Setup Script](../scripts/generate-pocketid-secrets) - Automated secrets generation
- [Nginx Reverse Proxy](./nginx.md) - Reverse proxy configuration
- [Secrets Management](./secrets.md) - Secrets and encryption key management
- [Security Best Practices](./security.md) - General security guidelines
