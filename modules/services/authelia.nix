{ config, pkgs, ... }:

{
  # Authelia: Single Sign-On and Portal
  # This instance is the central authority for all SKYLAB services.
  services.authelia.instances.main = {
    enable = true;

    # Secret Management:
    # We use the built-in secret options which automatically handle the environment variables
    # and configuration templates for sensitive data.
    secrets = {
      jwtSecretFile = "/var/lib/secrets/sso/authelia_identity_validation_reset_password_jwt_secret.secret";
      storageEncryptionKeyFile = "/var/lib/secrets/sso/authelia_storage_encryption_key.secret";
      sessionSecretFile = "/var/lib/secrets/sso/authelia_session_secret.secret";
      oidcHmacSecretFile = "/var/lib/secrets/sso/authelia_identity_providers_oidc_hmac_secret.secret";
      oidcIssuerPrivateKeyFile = "/var/lib/secrets/sso/authelia_identity_providers_oidc_jwks_0_key.secret";
    };

    # Additional environment variables for OIDC clients and Upstream providers
    environmentVariables = {
      AUTHELIA_IDENTITY_PROVIDERS_OIDC_CLIENTS_0_CLIENT_SECRET_FILE = "/var/lib/secrets/sso/authelia_identity_providers_oidc_clients_0_client_secret.secret";
      AUTHELIA_IDENTITY_PROVIDERS_OIDC_UPSTREAM_PROVIDERS_0_CLIENT_ID_FILE = "/var/lib/secrets/sso/authelia_identity_providers_oidc_upstream_providers_0_client_id.secret";
      AUTHELIA_IDENTITY_PROVIDERS_OIDC_UPSTREAM_PROVIDERS_0_CLIENT_SECRET_FILE = "/var/lib/secrets/sso/authelia_identity_providers_oidc_upstream_providers_0_client_secret.secret";
    };
    
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
        cors = {
          allowed_origins = [ "https://immich.skylab.local" ];
        };
        clients = [
          {
            client_id = "immich";
            client_name = "Immich Photo Management";
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
        # OIDC External Provider (Google)
        upstream = {
          providers = [
            {
              id = "google";
              issuer_base_url = "https://accounts.google.com";
            }
          ];
        };
      };
    };
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
        cors = {
          allowed_origins = [ "https://immich.skylab.local" ];
        };
        clients = [
          {
            client_id = "immich";
            client_name = "Immich Photo Management";
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
        # OIDC External Provider (Google)
        upstream = {
          providers = [
            {
              id = "google";
              issuer_base_url = "https://accounts.google.com";
            }
          ];
        };
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
}
