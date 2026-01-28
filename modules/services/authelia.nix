{ config, pkgs, ... }:

{
  # Authelia: Single Sign-On and Portal
  # This instance is the central authority for all SKYLAB services.
  services.authelia.instances.main = {
    enable = true;

    # Secret Management:
    # All sensitive keys are stored in a plain file deployed via scripts/deploy-secret.ts.
    # We inject them into the systemd service directly via EnvironmentFile.
    
    settings = {
      # The theme to use for the portal. Available options are 'light', 'dark', and 'grey'.
      theme = "dark";

      # Core Security Settings
      # Note: Actual secrets are injected via the environmentVariablesFile
      jwt_secret = "$AUTHELIA_JWT_SECRET";
      default_2fa_method = "totp";

      # The server section contains the configuration for the HTTP server.
      server = {
        host = "127.0.0.1";
        port = 9091;
      };

      # The log section contains the configuration for the logging.
      log = {
        level = "info";
        format = "text";
      };

      # The authentication_backend section contains the configuration for the authentication backend.
      # This is the primary source of user information. While we use Google OIDC for SSO,
      # Authelia requires a primary backend to manage its internal user representation.
      authentication_backend = {
        file = {
          path = "/var/lib/authelia-main/users.yml";
          search_email = true;
        };
      };

      # Authelia relies on session cookies to authorize user access to various protected websites.
      # This section configures the session cookie behavior and the domains which Authelia can service authorization requests for.
      session = {
        name = "authelia_session";
        expiration = "1h";
        inactivity = "5m";
        remember_me_duration = "1M";
        domain = "skylab.local";

        # We use Redis for high-performance, persistent session storage.
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
      # Rules are evaluated from top to bottom. The first matching rule is applied.
      access_control = {
        default_policy = "deny";
        rules = [
          # Local Network Bypass (Commented for testing)
          # {
          #   domain = [ "*.skylab.local" ];
          #   networks = [ "192.168.1.0/24" ];
          #   policy = "bypass";
          # }
          
          # General Protection:
          # For all other cases, require at least one-factor authentication (Google SSO).
          {
            domain = [ "*.skylab.local" ];
            policy = "one_factor";
          }
        ];
      };

      # The identity_providers.oidc section contains the configuration for the OpenID Connect identity provider.
      # This allows Authelia to act as an IdP for applications like Immich.
      identity_providers.oidc = {
        cors = {
          allowed_origins = [ "https://immich.skylab.local" ];
        };
        clients = [
          {
            id = "immich";
            description = "Immich Photo Management";
            # Secret set in environmentVariablesFile as AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_0_SECRET
            secret = "$AUTHELIA_IDENTITY_PROVIDERS_OIDC_IMMICH_SECRET";
            public = false;
            authorization_policy = "one_factor";
            redirect_uris = [
              "https://immich.skylab.local/auth/login"
              "https://immich.skylab.local/user-settings"
            ];
            scopes = [ "openid" "profile" "email" ];
            userinfo_signing_algorithm = "none";
          }
        ];
      };
    };
  };

  # Dependencies:
  # Authelia requires Redis for sessions and PostgreSQL for storage.
  services.redis.servers."".enable = true;

  # Ensure PostgreSQL is configured to allow the authelia database.
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "authelia" ];
    ensureUsers = [{
      name = "authelia";
      ensureDBOwnership = true;
    }];
  };

  # File permissions and directory structure
  systemd.tmpfiles.rules = [
    "d /var/lib/authelia-main 0700 authelia-main authelia-main -"
    "f /var/lib/authelia-main/users.yml 0600 authelia-main authelia-main - -"
  ];

  # Inject the environment file into the systemd service
  systemd.services.authelia-main.serviceConfig.EnvironmentFile = "/var/lib/secrets/sso/authelia.env";
}
