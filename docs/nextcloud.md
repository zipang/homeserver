# Nextcloud

Nextcloud is a self-hosted content collaboration platform that provides file storage, sharing, and communication tools.
The service is configured in `modules/services/nextcloud.nix`.

## Configuration Reference

The complete list of available options for the `services.nextcloud` module can be found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.nextcloud) (targeting the current NixOS version, 25.11).

## Full Configuration Template

You can use this template in `modules/services/nextcloud.nix` to configure the service. This configuration is optimized for security and performance using Unix sockets for both Database and Cache.

```nix
{ config, pkgs, lib, ... }:

{
  services.nextcloud = {
    enable = true;
    hostName = "nextcloud.skylab.local";
    
    # Package to use for the Nextcloud instance.
    package = pkgs.nextcloud32;

    # Nextcloud basic configuration
    config = {
      # Database type. 
      # Possible values: "sqlite", "pgsql", "mysql".
      dbtype = "pgsql";
      
      # Database host (+port) or socket path.
      # If dbtype is "pgsql", defaults to "/run/postgresql".
      dbhost = "/run/postgresql"; 
      
      # Database name.
      dbname = "nextcloud";
      
      # Database user.
      dbuser = "nextcloud";
      
      # The full path to a file that contains the database password.
      # Note: Peer Authentication is used over Unix sockets, so the password is 
      # not actually checked, but the NixOS module requires this option to be set.
      dbpassFile = "/var/lib/secrets/nextcloud/db_password";
      
      # The full path to a file that contains the admin's password.
      # Set only during the initial setup by nextcloud-setup.service.
      adminpassFile = "/var/lib/secrets/nextcloud/admin_password";
      
      # Username for the admin account. Only set during initial setup.
      # Since the username acts as unique ID internally, it cannot be changed later!
      adminuser = "admin";
      
      # Force Nextcloud to always use HTTP or HTTPS for link generation.
      # Possible values: "", "http", "https".
      overwriteProtocol = "https";
    };

    # Caching and Redis configuration
    configureRedis = false;
    caching.redis = true; # Load the Redis module into PHP
    
    settings = {
      redis = {
        host = "/run/redis/redis.sock";
        port = 0; # Required to indicate unix socket usage
        timeout = 1.5;
      };
      
      "memcache.local" = "\\OC\\Memcache\\APCu";
      "memcache.distributed" = "\\OC\\Memcache\\Redis";
      "memcache.locking" = "\\OC\\Memcache\\Redis";
      
      # Log level value between 0 (DEBUG) and 4 (FATAL).
      "loglevel" = 2; 
      
      # Logging backend to use.
      # Possible values: "errorlog", "file", "syslog", "systemd".
      "log_type" = "syslog";
    };


    # Caching and Redis configuration
    # We disable the auto-configuration of a local Redis to use our global one.
    configureRedis = false;
    
    # Load the Redis module into PHP.
    caching.redis = true;
    
    settings = {
      # Redis configuration for distributed caching and file locking.
      # Using Unix socket for better performance and security.
      redis = {
        host = "/run/redis/redis.sock";
        port = 0; # Required to indicate unix socket usage
        timeout = 1.5;
      };
      
      # Memory caching strategy
      "memcache.local" = "\\OC\\Memcache\\APCu";
      "memcache.distributed" = "\\OC\\Memcache\\Redis";
      "memcache.locking" = "\\OC\\Memcache\\Redis";
      
      # Security & Proxy
      # Trusted proxies, to provide if the nextcloud installation is being proxied.
      "trusted_proxies" = [ "127.0.0.1" ];
      
      # Maintenance window start (UTC)
      # Allows background jobs to run during low-traffic hours.
      "maintenance_window_start" = 1; # 1:00 AM UTC
      
      # Logging configuration
      "loglevel" = 2; # 2 (warn): warnings, errors and fatal errors.
      "log_type" = "syslog"; # Logging backend to use.
    };

    # Maximum upload size. This changes relevant options in php.ini and nginx.
    maxUploadSize = "16G";
    
    # Options for PHP's php.ini file.
    phpOptions = {
      "memory_limit" = lib.mkForce "4G"; 
      "max_execution_time" = "3600";
    };

    # Automatically enable apps listed in extraApps.
    extraAppsEnable = true;
    
    # Run a regular auto-update of all apps installed from the app store.
    autoUpdateApps.enable = true;

    # Tune PHP-FPM for Nextcloud performance.
    poolSettings = {
      "pm" = "dynamic";
      "pm.max_children" = "50";
      "pm.start_servers" = "5";
      "pm.min_spare_servers" = "5";
      "pm.max_spare_servers" = "35";
      "pm.max_requests" = "500";
    };
  };
}
```

## SSO Integration

Nextcloud is integrated with Authelia for Single Sign-On (SSO).
When accessing `https://nextcloud.skylab.local`, you will be redirected to Authelia if not already authenticated.

### Initial Admin Login

The initial administrator credentials are:
- **User**: `admin`
- **Password**: Found in `/var/lib/secrets/nextcloud/admin_password` (use `sudo cat` on the server)

## Operational Guides

### Secrets Management

Secrets are generated using the `scripts/generate-nextcloud-secrets.sh` script.
This script creates:
- `admin_password`: The initial admin account password.
- `db_password`: The password for the PostgreSQL user (compliance for the NixOS module).

### Database Management (Unix Sockets & Peer Auth)

The PostgreSQL database and user are automatically created by NixOS. By using `dbhost = "/run/postgresql"`, we enable **Peer Authentication**.

- **Security**: PostgreSQL verifies the OS user (`nextcloud`) matches the database user (`nextcloud`). No password is exchanged over the wire.
- **Initial Setup**: To set the database password (to satisfy the module's requirement for a password file):
```bash
sudo -u postgres psql -c "ALTER USER nextcloud WITH PASSWORD '$(sudo cat /var/lib/secrets/nextcloud/db_password)';"
```

### Redis Management (Unix Sockets)

We use a global Redis instance shared across services.
- **Socket Path**: `/run/redis/redis.sock`
- **Permissions**: The `nextcloud` user is added to the `redis` group in `authelia.nix` to gain access to the socket.

### Syncing Files

1.  **Desktop Clients**: Download the official Nextcloud client. Use `https://nextcloud.skylab.local` as the server address.
2.  **Mobile Clients**: Use the Nextcloud app on Android or iOS.

## Headless Operations & Troubleshooting

### View Service Logs

```bash
journalctl -u nextcloud-setup.service -f  # Setup and migrations
journalctl -u php-fpm-nextcloud.service -f # PHP engine logs
```

### OCC Command

Nextcloud's command-line interface (`occ`) is used for management tasks:

```bash
# General status
sudo -u nextcloud php /var/lib/nextcloud/occ status

# Maintenance mode
sudo -u nextcloud php /var/lib/nextcloud/occ maintenance:mode --on
sudo -u nextcloud php /var/lib/nextcloud/occ maintenance:mode --off
```

### Storage Location

Nextcloud data is stored in `/var/lib/nextcloud`, which is a ZFS dataset on the `WOODY` pool.
```bash
zfs list WOODY/nextcloud
```
