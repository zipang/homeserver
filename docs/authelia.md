# Authelia SSO Guide

## Overview

Authelia is an open-source authentication and authorization server providing two-factor authentication and single sign-on (SSO) for your applications via a web portal. 

In the SKYLAB ecosystem, Authelia serves as the **Identity Provider (IdP)**, bridging our local services with external authentication (Google OAuth) and providing granular access control.

*   **Module Path**: `modules/services/authelia.nix`
*   **Web Portal**: `https://auth.skylab.local`

## Configuration Reference

*   [Authelia Official Documentation](https://www.authelia.com/docs/)
*   [NixOS Options Search: Authelia](https://search.nixos.org/options?query=services.authelia)

## Architecture & Logic

### 1. Unified Authentication
*   **Access Control**: Authelia intercepts requests and requires a login.
*   **Local Network Bypass**: When accessing `*.skylab.local` from the home network (`192.168.1.0/24`), Authelia is configured to **bypass** authentication. This ensures a seamless experience while at home.

## Full Configuration Template

The service is defined in `modules/services/authelia.nix` and utilizes PostgreSQL for persistent storage and Redis for session management.

```nix
services.authelia.instances.main = {
  enable = true;
  
  # Recommended way to handle secrets in NixOS 25.11
  # We follow the "Standalone" naming convention for secrets.
  secrets = {
    # The secret used with the HMAC algorithm to sign the JWT. 
    # It is strongly recommended this is a Random Alphanumeric String with 64 or more characters.
    jwtSecretFile = "/var/lib/secrets/authelia/JWT_SECRET";

    # The secret to encrypt the session data. This is only used with Redis.
    sessionSecretFile = "/var/lib/secrets/authelia/SESSION_SECRET";

    # The encryption key that is used to encrypt sensitive information in the database. 
    # Must be a string with a minimum length of 20.
    storageEncryptionKeyFile = "/var/lib/secrets/authelia/STORAGE_ENCRYPTION_KEY";
  };

  settings = {
    theme = "dark";

    server = {
      address = "tcp://127.0.0.1:9091";
    };

    log = {
      level = "info";
      format = "text";
    };

    # Authentication Backend (Local Users File)
    # The users.yml file MUST be valid YAML. If empty, Authelia will fail.
    # Initialize with "users: {}" if no users are defined yet.
    authentication_backend = {
      file = {
        path = "/var/lib/authelia-main/users.yml";
      };
    };

    # Session Management (Redis)
    session = {
      name = "authelia_session";
      expiration = "1h";
      inactivity = "5m";
      remember_me = "1M";
      cookies = [
        {
          domain = "skylab.local"; 
          authelia_url = "https://auth.skylab.local";
        }
      ];
      
      redis = {
        host = "127.0.0.1";
        port = 6379;
      };
    };

    # Storage Backend (PostgreSQL via Unix Socket & Peer Auth)
    storage = {
      postgres = {
        address = "unix:///run/postgresql";
        database = "authelia-main";
        username = "authelia-main";
      };
    };

    # Access Control Rules
    access_control = {
      default_policy = "deny";
      rules = [
        # Local Network Bypass
        {
          domain = ["*.skylab.local"];
          networks = ["192.168.1.0/24"];
          policy = "bypass";
        }
        # General Protection (One Factor)
        # Restricted to users in the 'admins' group
        {
          domain = ["*.skylab.local"];
          subject = ["group:admins"];
          policy = "one_factor";
        }
      ];
    };

    # Notifier (Filesystem for local testing/setup)
    notifier = {
      filesystem = {
        filename = "/var/lib/authelia-main/notification.txt";
      };
    };
  };
};

# Dependencies
services.redis.servers."".enable = true;
services.postgresql = {
  enable = true;
  ensureDatabases = [ "authelia-main" ];
  ensureUsers = [{
    name = "authelia-main";
    ensureDBOwnership = true;
  }];
};
```

### Initial User Setup

To keep user details out of Git, the `users.yml` file is initialized manually on the server using the setup script. This script will prompt for your administrator username and email, generate a strong random password, and provide instructions on how to hash it for Authelia.

## Google Cloud Console Setup

To enable Google SSO, you must create an OAuth 2.0 Client in the [Google Cloud Console](https://console.cloud.google.com/).

### 1. Create a Project
- Create a new project (e.g., `SKYLAB-SSO`).

### 2. Configure OAuth Consent Screen
- Go to **APIs & Services > OAuth consent screen**.
- Select **External** (unless you have a Google Workspace org).
- Fill in the required app information.
- Inside **Data Access** add the following scopes (data shared with our Authelia Client): `.../auth/userinfo.email`, `.../auth/userinfo.profile`, and `openid`.

### 3. Create Credentials
- Go to **APIs & Services > Credentials**.
- Click **Create Credentials > OAuth client ID**.
- Application type: **Web application**.
- Name: `Authelia SKYLAB`.
- **Authorized JavaScript origins**:
  - `https://auth.skylab.local`
- **Authorized redirect URIs**:
  - `https://auth.skylab.local/api/oidc/authorization`

### 4. Get your Keys
- Copy the **Client ID** and **Client Secret**. These will be used when configuring the OIDC upstream provider.

## Secret Management & Operations

Authelia requires several high-entropy secrets. We use specialized scripts to manage the lifecycle of the Authelia instance.

### 1. Generating Secrets (Safe)
The `generate-authelia-secrets.sh` script creates the required secrets only if they do not exist. It ensures correct permissions and ownership.

Run this once before the first deployment, or whenever you need to ensure missing secrets are present:
```bash
sudo ./scripts/generate-authelia-secrets.sh
```

**Secrets Generated:**
- `JWT_SECRET`: Used to sign/verify JWTs (64 chars hex).
- `SESSION_SECRET`: Used for Redis session encryption.
- `STORAGE_ENCRYPTION_KEY`: Used to encrypt database content.

### 2. Dropping the Instance (Dangerous)
If you need to start from a completely fresh state (e.g., after a major configuration change or for testing), use the `drop-authelia-instance.sh` script.

**Warning**: This will stop the service, drop the PostgreSQL database, and delete all secrets and state files.
```bash
sudo ./scripts/drop-authelia-instance.sh
```

## Nginx Integration (auth_request)

For services that do not support OIDC natively (like Syncthing), we use Nginx's `auth_request` module.

### Nginx VHost Configuration
```nginx
location / {
    auth_request /authelia;
    auth_request_set $target_url $scheme://$http_host$request_uri;
    error_page 401 = &https://auth.skylab.local/?rd=$target_url;
    
    proxy_pass http://127.0.0.1:8384;
}

location /authelia {
    internal;
    proxy_pass http://127.0.0.1:9091/api/verify;
    # ... required proxy headers
}
```

## Operational Guides

### Checking Logs
Monitor Authelia's activity (login attempts, rule matching):
```bash
journalctl -u authelia-main.service -f
```

### Database Management
Authelia's tables are managed automatically by the service. To check the database status:
```bash
sudo -u postgres psql -d authelia -c "\dt"
```

## Related Files
*   `modules/services/authelia.nix`: Core service configuration.
*   `modules/services/nginx.nix`: Proxy and `auth_request` middleware.
*   `scripts/generate-authelia-secrets.sh`: Secret generation script.
*   `scripts/drop-authelia-instance.sh`: Instance cleanup script.
