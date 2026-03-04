{ config, pkgs, ... }:

{
  services.jellyfin = {
    enable = true;
    group = "users";      # Run in users group for shared file access
    openFirewall = false; # We use Nginx as a reverse proxy
  };

  # Hardware acceleration for Jellyfin (AMD Radeon RX Vega M GH)
  # jellyfin user needs access to video/render devices and users group
  users.users.jellyfin.extraGroups = [ "video" "render" "users" ];

  # Set file permissions: 664 for files (rw-rw-r--), 775 for directories
  systemd.services.jellyfin.serviceConfig.UMask = "0002";

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
