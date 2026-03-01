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
      
      # Ensure ZFS monitoring is prioritized
      plugins = {
        "zfs" = "yes";
        "proc" = "yes";
      };
    };
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
