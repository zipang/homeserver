{ config, pkgs, lib, ... }:

{
  services.pocket-id = {
    # Whether to enable the Pocket ID OIDC provider service.
    enable = true;

    # Override default user/group to avoid hyphen issues in PostgreSQL
    user = "pocketid";
    group = "pocketid";

    # Sensitive data (ENCRYPTION_KEY) is loaded from this file.
    # It must contain: ENCRYPTION_KEY=...
    environmentFile = "/var/lib/secrets/pocketid.env";

    # Public configuration is set in settings (this goes into the Nix store)
    settings = {
      APP_URL = "https://pocketid.${config.server.privateDomain}";
      TRUST_PROXY = true;
      DB_PROVIDER = "postgres";
      DB_CONNECTION_STRING = "host=/run/postgresql user=pocketid database=pocketid";
      KEYS_STORAGE = "database";
    };
  };

  # Additional systemd service configuration
  systemd.services.pocket-id = {
    serviceConfig = {
      # Allow reading secrets from /var/lib/secrets (since ProtectSystem=strict is active)
      ReadWritePaths = [ "/var/lib/secrets" ];
    };

    # Ensure PostgreSQL starts before Pocketid
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
  };

  # Allow the pocketid user to access PostgreSQL socket
  users.users.pocketid = {
    isSystemUser = true;
    group = "pocketid";
    extraGroups = [ "postgres" ];
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
}
