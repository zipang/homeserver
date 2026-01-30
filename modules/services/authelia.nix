{ config, pkgs, ... }:

{
  # Authelia: Single Sign-On and Portal
  # This instance is the central authority for all SKYLAB services.
  services.authelia.instances.main = {
    enable = true;

    # Secret Management:
    # We follow the "Standalone" naming convention for secrets.
    # Paths are stored in /var/lib/secrets/authelia/
    secrets = {
      # The secret used with the HMAC algorithm to sign the JWT. 
      # It is strongly recommended this is a Random Alphanumeric String with 64 or more characters.
      jwtSecretFile = "/var/lib/secrets/authelia/JWT_SECRET";

      # The encryption key that is used to encrypt sensitive information in the database. 
      # Must be a string with a minimum length of 20.
      storageEncryptionKeyFile = "/var/lib/secrets/authelia/STORAGE_ENCRYPTION_KEY";

      # The secret to encrypt the session data. This is only used with Redis.
      sessionSecretFile = "/var/lib/secrets/authelia/SESSION_SECRET";
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

      notifier = {
        filesystem = {
          filename = "/var/lib/authelia-main/notification.txt";
        };
      };

      authentication_backend = {
        file = {
          path = "/var/lib/authelia-main/users.yml";
        };
      };

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
            host = "/run/redis/redis.sock";
            port = 0; # Required when using a unix socket
          };
        };


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
          {
            domain = [ "*.skylab.local" ];
            networks = [ "192.168.1.0/24" ];
            policy = "bypass";
          }
          {
            domain = [ "nextcloud.skylab.local" ];
            subject = [ "group:admins" ];
            policy = "one_factor";
          }
          {
            domain = [ "*.skylab.local" ];
            subject = [ "group:admins" ];
            policy = "one_factor";
          }
        ];
      };
    };
  };

  # Allow services to access the shared sockets
  users.users.authelia-main.extraGroups = [ "redis" "postgres" ];

  services.postgresql = {
    ensureDatabases = [ "authelia-main" ];
    ensureUsers = [
      {
        name = "authelia-main";
        ensureDBOwnership = true;
      }
    ];
  };

  # File permissions and directory structure
  systemd.tmpfiles.rules = [
    "d /var/lib/authelia-main 0700 authelia-main authelia-main -"
    "d /var/lib/secrets/authelia 0700 authelia-main authelia-main -"
  ];
}
