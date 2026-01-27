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

## Headless Operations & Troubleshooting

### Monitoring Logs
Since Immich is split into several services on NixOS, you may need to check logs for specific components:
* **Main Server**: `journalctl -u immich-server.service -f`
* **Microservices**: `journalctl -u immich-microservices.service -f`
* **Machine Learning**: `journalctl -u immich-machine-learning.service -f`

### Common Issues

#### 1. 502 Bad Gateway
If Nginx reports a 502 error, the `immich-server` is likely failing to start or restarting in a loop. 
Check `systemctl status immich-server.service`.

#### 2. PostgresError: must be owner of extension vectors
During updates or migrations, Immich may try to drop the legacy `vectors` extension but fail due to permissions.
**Fix**: Run this manually as the database superuser:
```bash
sudo -u postgres psql -d immich -c "DROP EXTENSION IF EXISTS vectors CASCADE;"
```

#### 3. Folder Integrity Check (Missing .immich file)
Immich requires a hidden `.immich` file in every storage subfolder to prevent data loss if a disk is unmounted. If these are missing, the server will crash on startup.
**Fix**: Create the markers:
```bash
sudo touch /var/lib/immich/{upload,library,thumbs,backups,profile,encoded-video}/.immich
sudo chown -R immich:immich /var/lib/immich
```

### Fresh Re-install (Factory Reset)
If the database or storage state is corrupted and you wish to start from scratch:
1. Comment out the Immich import in `hosts/SKYLAB/configuration.nix`.
2. Run `sudo nixos-rebuild switch --flake .#SKYLAB`.
3. Execute the cleanup script: `sudo ./scripts/drop-immich.sh`.
4. Uncomment the import and rebuild again.

