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

### 1. Hybrid Authentication Flow
*   **Internal Access**: When accessing `*.skylab.local` from the home network (`192.168.1.0/24`), Authelia is configured to **bypass** authentication. This ensures a seamless experience while at home.
*   **External Access**: When accessing via the public domain or non-local networks, Authelia intercepts the request and requires a login (Google SSO).

### 2. OIDC Provider
Authelia acts as an OpenID Connect (OIDC) provider for modern applications like **Immich**, allowing them to delegate user management and login entirely to Authelia.

## Full Configuration Template

The service is defined in `modules/services/authelia.nix` and utilizes PostgreSQL for persistent storage and Redis for session management.

```nix
services.authelia.instances.main = {
  enable = true;
  
  # Recommended way to handle secrets in NixOS 25.11
  secrets = {
    jwtSecretFile = "/var/lib/secrets/sso/authelia_identity_validation_reset_password_jwt_secret.secret";
    storageEncryptionKeyFile = "/var/lib/secrets/sso/authelia_storage_encryption_key.secret";
    # ... other secret files
  };

  settings = {
    # ... 
  };
};
    theme = "dark";

    # The server section contains the configuration for the HTTP server.
    server = {
      host = "127.0.0.1";
      port = 9091;
    };

    # The authentication_backend section contains the configuration for the authentication backend.
    authentication_backend = {
      file = {
        path = "/var/lib/authelia-main/users.yml";
        search_email = true;
      };
    };

    # The session section contains the configuration for the session management.
    session = {
      name = "authelia_session";
      expiration = "1h";
      inactivity = "5m";
      remember_me_duration = "1M";
      domain = "skylab.local"; 
      
      # The session.redis section contains the configuration for the Redis session storage.
      redis = {
        host = "127.0.0.1";
        port = 6379;
      };
    };

    # Authelia supports multiple storage backends. The backend is used to store user 
    # preferences, 2FA device handles and secrets, authentication logs, etc…
    storage = {
      # The storage.postgres section contains the configuration for the PostgreSQL storage backend.
      postgres = {
        address = "tcp://127.0.0.1:5432";
        database = "authelia";
        username = "authelia";
      };
    };

    # The access_control section contains the configuration for the access control rules.
    access_control = {
      default_policy = "deny";
      rules = [
        # Local Network Bypass
        {
          domain = ["*.skylab.local"];
          networks = ["192.168.1.0/24"];
          policy = "bypass";
        }
        # General Protection (Google SSO)
        {
          domain = ["*.skylab.local"];
          policy = "one_factor";
        }
      ];
    };

    # The identity_providers.oidc section contains the configuration for the OpenID Connect identity provider.
    identity_providers.oidc = {
      clients = [
        {
          id = "immich";
          secret = "$AUTHELIA_IDENTITY_PROVIDERS_OIDC_IMMICH_SECRET";
          redirect_uris = ["https://immich.skylab.local/auth/login"];
        }
      ];
    };
  };
};
```

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
- Copy the **Client ID** and **Client Secret**. These will be used when running the `generate-secrets.ts` script.

## Secret Management (Secret Deployer)

Authelia requires several high-entropy secrets. We use a **Bun + TypeScript** deployer to handle this without putting secrets in Git. 

> **Security Note**: As SOPS encryption was causing issues, secrets are currently stored in a plain file on the server with restricted permissions (600). The script must be run with `sudo`.

### 1. The Template
The template file `secrets/authelia.env` defines how each secret is generated:
- `KEY=command`: Executes the command to generate the value.
- `KEY=prompt("message")`: Interactively asks for the value.

### 2. Running the Deployer
Run the script on the SKYLAB server:
```bash
sudo bun scripts/deploy-secret.ts \
  --template authelia.env \
  --outputDir /var/lib/secrets/sso
```
The script will:
- Parse the template.
- Execute generation commands (like `openssl rand`).
- Prompt for manual secrets (Google OAuth keys).
- Save the unencrypted result to `/var/lib/secrets/sso/authelia.env` with 600 permissions.

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
*   `scripts/deploy-secret.ts`: Secret deployment script.
*   `secrets/authelia.env`: Generation template.
