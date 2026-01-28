{ config, pkgs, ... }:

{
  # Authelia: Single Sign-On and Portal
  # This instance is the central authority for all SKYLAB services.
  services.authelia.instances.main = {
    enable = true;

    # Secret Management:
    # All sensitive keys are stored in a plain file deployed via scripts/deploy-secret.ts.
    # We inject them into the systemd service directly via EnvironmentFile.
    # We set manual = true to bypass the module's built-in secret assertions.
    secrets.manual = true;
    
    settings = {
      # The theme to use for the portal. Available options are 'light', 'dark', and 'grey'.
      theme = "dark";

      # The server section contains the configuration for the HTTP server.
      server = {
        address = "tcp://127.0.0.1:9091";
      };

      # The log section contains the configuration for the logging.
      log = {
        level = "info";
        format = "text";
      };

      # Identity Validation (JWT Secret moved here in v4.38.0)
      identity_validation = {
        reset_password.jwt_secret = "AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET";
      };

      # Notifier is mandatory (using filesystem for now)
      notifier = {
        filesystem = {
          filename = "/var/lib/authelia-main/notification.txt";
        };
      };

      # The authentication_backend section contains the configuration for the authentication backend.
      authentication_backend = {
        file = {
          path = "/var/lib/authelia-main/users.yml";
        };
        # OIDC External Provider (Google)
        oidc = {
          google = {
            issuer_base_url = "https://accounts.google.com";
            # client_id and client_secret are injected via:
            # AUTHELIA_AUTHENTICATION_BACKEND_OIDC_GOOGLE_CLIENT_ID
            # AUTHELIA_AUTHENTICATION_BACKEND_OIDC_GOOGLE_CLIENT_SECRET
          };
        };
      };

      # Authelia relies on session cookies to authorize user access to various protected websites.
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

        # We use Redis for high-performance, persistent session storage.
        redis = {
          host = "127.0.0.1";
          port = 6379;
        };
      };

      # Authelia supports multiple storage backends.
      storage = {
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
          # General Protection:
          # For all other cases, require at least one-factor authentication (Google SSO).
          {
            domain = [ "*.skylab.local" ];
            policy = "one_factor";
          }
        ];
      };

      # The identity_providers.oidc section contains the configuration for the OpenID Connect identity provider.
      identity_providers.oidc = {
        jwks = [
          {
            key = "AUTHELIA_IDENTITY_PROVIDERS_OIDC_JWKS_0_KEY";
          }
        ];
        cors = {
          allowed_origins = [ "https://immich.skylab.local" ];
        };
        clients = [
          {
            client_id = "immich";
            client_name = "Immich Photo Management";
            # client_secret is injected via environment variable:
            # AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_0_CLIENT_SECRET
            public = false;
            authorization_policy = "one_factor";
            redirect_uris = [
              "https://immich.skylab.local/auth/login"
              "https://immich.skylab.local/user-settings"
            ];
            scopes = [ "openid" "profile" "email" ];
            userinfo_signed_response_alg = "none";
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
