{ config, pkgs, ... }:

{
  services.jellyfin = {
    enable = true;
    openFirewall = false; # We use Nginx as a reverse proxy
  };

  # Hardware acceleration for Jellyfin (AMD Radeon RX Vega M GH)
  # We use VAAPI via the Mesa 'radeonsi' driver.
  # Added 'postgres' group for peer authentication to the local database.
  users.users.jellyfin.extraGroups = [ "video" "render" "postgres" ];

  systemd.services.jellyfin = {
    # Configure Jellyfin to use PostgreSQL via environment variables
    # Supported in Jellyfin 10.9.0+
    environment = {
      JELLYFIN_Database__Type = "PostgreSQL";
      JELLYFIN_Database__ConnectionString = "Host=/run/postgresql;Database=jellyfin;Username=jellyfin";
    };
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
  };

  # Nginx Reverse Proxy Configuration
  services.nginx.virtualHosts."jellyfin.skylab.local" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
    
    locations."/" = {
      proxyPass = "http://127.0.0.1:8096";
      proxyWebsockets = true;
      extraConfig = ''
        # Disable buffering for better streaming performance
        proxy_buffering off;
        
        # Dedicated logging for debugging (400 error investigation)
        access_log /var/log/nginx/jellyfin.access.log;
        error_log /var/log/nginx/jellyfin.error.log info;
      '';
    };
  };

  # Essential packages for AMD VAAPI hardware acceleration
  environment.systemPackages = with pkgs; [
    libva
    libva-utils
    mesa # Provides 'radeonsi' VAAPI driver for AMD
    vulkan-loader
    vulkan-tools
    clinfo # To verify OpenCL if needed
  ];
}
