{ config, pkgs, lib, ... }:

{
  services.netdata = {
    enable = true;
    package = pkgs.netdata;
    
    # Optimize for performance and storage
    config = {
      global = {
        "history main cache size" = "128"; # RAM cache size in MB
        "dbengine multihost disk space" = "1024"; # Retention size in MB
        "memory mode" = "dbengine";
      };
      
      # Ensure ZFS monitoring is prioritized and necessary plugins are enabled
      plugins = {
        "zfs" = "yes";
        "proc" = "yes";
        "postgresql" = "yes"; 
        "ipmi" = "yes";       
      };
      
      # Inject raw configuration lines to fix socket path and IPMI warnings
      # This syntax uses key-value pairs for config injection.
      "plugin:postgresql" = "socket: /var/run/postgresql/.s.PGSQL.5432";
      "plugin:ipmi" = "error_level: WARN";
    };
  };

  # Dependency configuration for IPMI: Kernel Modules
  boot.kernelModules = [ "ipmi_si" "ipmi_devintf" ];

  # Dependency configuration for IPMI: User Permissions
  users.users.netdata = {
    extraGroups = [ "ipmi" ];
  };

  # Nginx Reverse Proxy (Private Domain with Local SSL)
  services.nginx.virtualHosts."monitor.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:19999";
      proxyWebsockets = true;
    };
  };
}