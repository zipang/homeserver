{ config, pkgs, ... }:

{
  services.pocket-id = {
    # Whether to enable the Pocket ID OIDC provider service.
    enable = true;

    # The host to listen on (127.0.0.1 for local access only, behind Nginx).
    host = "127.0.0.1";

    # The port to listen on.
    port = 1411;

    # Database configuration - using shared PostgreSQL instance
    database = {
      # Use PostgreSQL instead of SQLite
      type = "postgres";
      
      # Connection string - will be loaded from environment variable in systemd service
      # Format: postgresql://user:password@host:port/database
      # We use environment file to inject this securely
    };
  };

  # Configure systemd service to load environment variables from secrets file
  systemd.services.pocket-id = {
    # Load environment from the secrets file
    environmentFiles = [ "/var/lib/secrets/pocketid.env" ];

    # Ensure PostgreSQL starts before Pocketid
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
  };

  # Ensure the pocket-id user can read the secrets file
  users.users.pocket-id.extraGroups = [ ];

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

  # Ensure the secrets directory and file exist with proper permissions
  # Note: The actual pocketid.env file must be created manually with:
  #   sudo touch /var/lib/secrets/pocketid.env
  #   sudo chmod 600 /var/lib/secrets/pocketid.env
  #   sudo chown pocket-id:pocket-id /var/lib/secrets/pocketid.env
  #   
  # And populated with environment variables:
  #   APP_URL=https://pocketid.skylab.local
  #   ENCRYPTION_KEY=<base64-encoded-32-byte-key>
  #   TRUST_PROXY=true
  #   PORT=1411
  #   HOST=127.0.0.1
  #   DB_CONNECTION_STRING=postgresql://pocketid:PASSWORD@localhost/pocketid
  #   ALLOW_USER_SIGNUPS=disabled
  #   LOG_LEVEL=info

  # Ensure the /var/lib/secrets directory exists
  system.activationScripts.pocketidSecretsDir = ''
    mkdir -p /var/lib/secrets
    chmod 700 /var/lib/secrets
  '';
}
