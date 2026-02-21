{ config, pkgs, lib, ... }:

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

  # Additional systemd service configuration
  systemd.services.pocket-id = {
    serviceConfig = {
      # Allow reading secrets from /var/lib/secrets
      ReadWritePaths = [ "/var/lib/secrets" ];
    };

    # Ensure PostgreSQL starts before Pocketid
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
  };

  # Explicitly define the pocketid user and group
  users.users.pocketid = {
    isSystemUser = true;
    group = "pocketid";
    extraGroups = [ "postgres" ];
    home = "/var/lib/pocketid";
    createHome = true;
  };

  users.groups.pocketid = {};

  # Configure Nginx reverse proxy for Pocketid
  services.nginx.virtualHosts."pocketid.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    # SvelteKit (used by Pocketid) generates large headers
    # These buffer settings are required to avoid "431 Request Header Fields Too Large" errors
    extraConfig = ''
      proxy_busy_buffers_size 512k;
      proxy_buffers 4 512k;
      proxy_buffer_size 256k;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:1411";
      proxyWebsockets = true;

      # Pass the X-Forwarded-For header so Pocketid knows the real client IP
      extraConfig = ''
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

  # Ensure the /var/lib/secrets directory exists for the secrets file
  system.activationScripts.pocketidSecretsDir = ''
    mkdir -p /var/lib/secrets
    # Set directory permissions to 755 to allow services to read their secret files
    # Individual secret files should have 600 permissions for security
    chmod 755 /var/lib/secrets
  '';

  # Ensure the data directory and subdirectories exist with correct permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/pocketid 0750 pocketid pocketid -"
    "d /var/lib/pocketid/data 0750 pocketid pocketid -"
    "d /var/lib/pocketid/data/uploads 0750 pocketid pocketid -"
    "d /var/lib/pocketid/data/uploads/application-images 0750 pocketid pocketid -"
  ];
}
