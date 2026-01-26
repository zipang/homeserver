# Immich Service Documentation

## Overview
Immich is a high-performance self-hosted photo and video management solution. 
NixOS Module: `modules/services/immich.nix`

## Configuration Reference
* [NixOS Options Search: services.immich](https://search.nixos.org/options?channel=25.11&query=services.immich)

## Full Configuration Template
```nix
{ config, pkgs, ... }:

{
  services.immich = {
    # Whether to enable the Immich service.
    enable = true;

    # The IP address to listen on.
    host = "127.0.0.1";

    # The port to listen on.
    port = 2283;

    # The location where the uploaded media is stored.
    mediaLocation = "/var/lib/immich";

    # The user to run the Immich service as.
    # user = "immich";

    # The group to run the Immich service as.
    # group = "immich";

    # Whether to open the firewall for the Immich port.
    # openFirewall = false;

    # Database configuration
    database = {
      # Whether to enable the local PostgreSQL database. 
      # If enabled, a local PostgreSQL instance will be automatically configured.
      enable = true;

      # The host of the PostgreSQL database.
      # host = "localhost";

      # The port of the PostgreSQL database.
      # port = 5432;

      # The name of the PostgreSQL database.
      # name = "immich";

      # The user of the PostgreSQL database.
      # user = "immich";

      # File containing the password for the database user.
      # passwordFile = "/run/secrets/immich-db-password";
    };

    # Redis configuration
    redis = {
      # Whether to enable the local Redis instance.
      # If enabled, a local Redis instance will be automatically configured.
      enable = true;

      # The host of the Redis instance.
      # host = "localhost";

      # The port of the Redis instance.
      # port = 6379;
    };

    # Machine learning service configuration
    machine-learning = {
      # Whether to enable the machine learning service.
      enable = true;

      # The host of the machine learning service.
      # host = "localhost";

      # The port of the machine learning service.
      # port = 3003;
    };

    # Extra environment variables to pass to the Immich server.
    # environment = {
    #   IMMICH_LOG_LEVEL = "log";
    # };

    # File containing secrets to pass to the Immich server (like DB password).
    # secretsFile = "/run/secrets/immich-secrets";
  };

  # Configure Nginx for Immich
  services.nginx.virtualHosts."immich.skylab.local" = {
    # Security: Only allow local network access
    extraConfig = ''
      allow 192.168.1.0/24;
      allow 127.0.0.1;
      deny all;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 0;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        send_timeout 600s;
      '';
    };
  };

  # Ensure the immich user can read the bind-mounted photos
  users.users.immich.extraGroups = [ "zipang" ];
  
  # Add zipang to the immich group to manage the generated thumbnails/metadata if needed
  users.users.zipang.extraGroups = [ "immich" ];
}
```

## Immich Public Proxy (Optional)
[Immich Public Proxy](https://github.com/alangrainger/immich-public-proxy) (IPP) allows you to share albums publicly without exposing your full Immich instance.

### Configuration Template
```nix
{ config, pkgs, ... }:

{
  services.immich-public-proxy = {
    # Whether to enable the Immich Public Proxy service.
    enable = true;

    # URL of the Immich instance.
    immichUrl = "http://localhost:2283";

    # The port that IPP will listen on.
    port = 3000;

    # Whether to open the IPP port in the firewall.
    # openFirewall = false;

    # Configuration for IPP.
    # settings = {
    #   # See https://github.com/alangrainger/immich-public-proxy/blob/main/README.md#additional-configuration
    # };
  };
}
```

## Storage Strategy
* **Managed Data**: Thumbnails, encoded videos, and database are stored in `/var/lib/immich`.
* **External Library**: Existing photos are exposed via a bind mount from `/home/zipang/Pictures/Digicam` to `/media/immich`.
  * Configure this in the Immich UI under **Administration > Libraries > External Libraries**.

## Operational Guides

### Local Network Access
Access the service at: [http://immich.skylab.local](http://immich.skylab.local)

### mDNS / DNS Resolution
Ensure your client can resolve `.local` domains (e.g., via Avahi on the server).

## Headless Operations & Troubleshooting
* **Logs Monitoring**: `journalctl -u immich.service -f`
* **Status Check**: `systemctl status immich.service`
* **Microservices**: Immich runs several microservices (server, machine-learning, etc.). Check them if some features are missing.
* **Database**: `systemctl status postgresql.service`
