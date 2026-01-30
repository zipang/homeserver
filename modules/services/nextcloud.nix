{ config, pkgs, lib, ... }:

{
  services.nextcloud = {
    enable = true;
    hostName = "nextcloud.skylab.local";
    
    # Package to use for the Nextcloud instance.
    # We target Nextcloud 32 (latest stable).
    package = pkgs.nextcloud32;

    # Nextcloud basic configuration
    config = {
      # Database type. Possible values: sqlite, pgsql, mysql.
      dbtype = "pgsql";
      
      # Database host (+port) or socket path.
      # For PostgreSQL on local Unix socket, we use the standard NixOS path.
      dbhost = "/run/postgresql"; 
      
      # Database name.
      dbname = "nextcloud";
      
      # Database user.
      dbuser = "nextcloud";
      
      # The full path to a file that contains the database password.
      # Note: We use Peer Authentication via Unix socket, so this password is 
      # not strictly used by PostgreSQL, but the NixOS module requires it.
      dbpassFile = "/var/lib/secrets/nextcloud/db_password";
      
      # The full path to a file that contains the admin's password.
      # Set only during the initial setup by nextcloud-setup.service.
      adminpassFile = "/var/lib/secrets/nextcloud/admin_password";
      
      # Username for the admin account. Only set during initial setup.
      adminuser = "admin";
      
      # Force Nextcloud to always use HTTPS for link generation.
      overwriteProtocol = "https";
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
    # These are additive to the defaults provided by the module.
    phpOptions = {
      "upload_max_filesize" = "16G";
      "post_max_size" = "16G";
      "memory_limit" = "1G"; # Increased for better performance with large files
      "max_execution_time" = "3600"; # Increased for long-running uploads/tasks
    };

    # Automatically enable apps listed in extraApps.
    extraAppsEnable = true;
    
    # Run a regular auto-update of all apps installed from the app store.
    autoUpdateApps.enable = true;
  };

  # Tune PHP-FPM for Nextcloud performance.
  # These values are recommended for a server with at least 4GiB of RAM.
  services.phpfpm.pools.nextcloud.settings = {
    "pm" = "dynamic";
    "pm.max_children" = 50;
    "pm.start_servers" = 5;
    "pm.min_spare_servers" = 5;
    "pm.max_spare_servers" = 35;
    "pm.max_requests" = 500;
  };

  # Database and Group Configuration
  users.users.nextcloud.extraGroups = [ "redis" "postgres" ];

  services.postgresql = {
    ensureDatabases = [ "nextcloud" ];
    ensureUsers = [
      {
        name = "nextcloud";
        ensureDBOwnership = true;
      }
    ];
  };

  # Secret directory structure (managed by systemd tmpfiles)
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/nextcloud 0700 nextcloud nextcloud -"
  ];
}
