{ config, pkgs, lib, ... }:

{
  services.netdata = {
    enable = true;
    package = pkgs.netdata;
    
    # Optimize for performance and storage
    config = {
      global = {
        "memory mode" = "none"; # Disable local metric storage entirely
      };
      
      # Ensure ZFS monitoring is prioritized and necessary plugins are enabled
      plugins = {
        "zfs" = "yes";
        "proc" = "yes";
        "postgresql" = "no"; # Disabled due to authentication issues and lack of requirement
        "ipmi" = "yes";       
      };
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
