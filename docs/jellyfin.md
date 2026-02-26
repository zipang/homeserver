# Jellyfin Service

## Overview

Jellyfin is a free and open-source media system that allows users to manage and stream their media (movies, music, photos) to various devices.

- **Module Path**: `modules/services/jellyfin.nix`
- **Reverse Proxy**: `jellyfin.skylab.local`
- **Official Documentation**: [jellyfin.org/docs](https://jellyfin.org/docs/general/server/settings/)
- **Environment Variables**: [jellyfin.org/docs/general/administration/configuration](https://jellyfin.org/docs/general/administration/configuration#environment-variables)
- **Database Options**: [jellyfin.org/docs/general/administration/database](https://jellyfin.org/docs/general/administration/database)

## Configuration Reference

Refer to the official [NixOS Search: services.jellyfin](https://search.nixos.org/options?channel=25.11&query=services.jellyfin) for full documentation.

## Full Configuration Template

```nix
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
        
        # Dedicated logging for debugging
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
```

## Operational Guides

### Initial Setup

1.  After deployment, access the web interface at `https://jellyfin.skylab.local`.
2.  Follow the setup wizard to create an admin account.
3.  **Hardware Acceleration (AMD GPU)**: 
    - Go to **Dashboard > Playback**.
    - Transcoding:
      - Hardware acceleration: **Video Acceleration API (VAAPI)**.
      - VAAPI Device: Use the render node corresponding to the AMD GPU (usually `/dev/dri/renderD128` or `/dev/dri/renderD129`).
    - To identify the correct node:
      ```bash
      ls -l /dev/dri/by-path/
      ```
      Look for the path containing `pci-0000:01:00.0` (which is the typical address for the Vega M on this NUC) and see which `renderDxxx` it links to.

### Database Integration

Jellyfin is configured to use a dedicated PostgreSQL database.
-   **Database**: `jellyfin`
-   **User**: `jellyfin`
-   **Connection**: Unix socket (Peer authentication)

**Note**: Switching from SQLite to PostgreSQL will result in a fresh Jellyfin instance. Existing data must be manually migrated if necessary.

## Headless Operations & Troubleshooting

- **Check service status**:
  ```bash
  systemctl status jellyfin
  ```
- **Monitor logs**:
  ```bash
  journalctl -u jellyfin -f
  ```
- **Nginx Access/Error Logs**:
  ```bash
  tail -f /var/log/nginx/jellyfin.access.log
  tail -f /var/log/nginx/jellyfin.error.log
  ```
- **Test VAAPI access**:
  ```bash
  sudo -u jellyfin vainfo
  ```
  Ensure the output shows `Driver version: Mesa radeonsi`.
