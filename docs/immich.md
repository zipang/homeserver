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
* **Managed Data**: Managed uploads, thumbnails, and encoded videos are stored in `/var/lib/immich` (on the SSD pool **BUZZ** for performance).
* **External Library**: Existing photo collections are stored on `/share/Storage/WOODY/photos` (on the HDD mirror pool **WOODY**).
  * To connect them: Configure an **External Library** in the Immich UI under **Administration > Libraries**.
  * Path to use in the UI: `/share/Storage/WOODY/photos`

## Operational Guides

### Local Network Access
Access the service at: [http://immich.skylab.local](http://immich.skylab.local)

### DNS Resolution (Local Domain)
Since we are using a virtual domain name (`immich.skylab.local`) that is not known by your router's DNS, you need to manually tell your client machines how to find it using the **hosts file**.

#### Static DNS Mapping (Hosts file)
This is the simplest method for local resolution without a dedicated DNS server. You manually map the domain name to the server's IP address.

1. Find the local IP address of the SKYLAB server (e.g., `192.168.1.XX`).
2. Edit the `/etc/hosts` file on your client machine (requires `sudo`):
   ```bash
   sudo nano /etc/hosts
   ```
3. Add the following line at the end:
   ```text
   192.168.1.XX  immich.skylab.local
   ```
   *(Replace `192.168.1.XX` with the actual IP of SKYLAB)*

### How to reload /etc/hosts without rebooting
Changes to `/etc/hosts` are usually picked up immediately by the operating system's resolver. However, applications like web browsers often cache DNS results.

If the change doesn't seem to work, you can force a refresh:

*   **Flush System DNS Cache (Linux with systemd-resolved):**
    ```bash
    sudo resolvectl flush-caches
    ```
*   **Restart Browser**: Close and reopen your web browser to clear its internal DNS cache.
*   **Check with ping**: Run `ping immich.skylab.local` to verify the IP mapping is active.

## Performance & Memory Usage
Immich is a feature-rich service that includes machine learning capabilities (object detection, face recognition). 

*   **Memory Footprint**: Enabling Immich can significantly increase system memory usage (around 1.5 - 2 GiB additional RAM).
*   **Machine Learning**: The `machine-learning` service is the most resource-intensive part. If memory becomes a critical issue, some ML features can be tuned or disabled in the configuration.
* **Logs Monitoring**: `journalctl -u immich.service -f`
* **Status Check**: `systemctl status immich.service`
* **Microservices**: Immich runs several microservices (server, machine-learning, etc.). Check them if some features are missing.
* **Database**: `systemctl status postgresql.service`
