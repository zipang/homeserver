{ config, pkgs, lib, ... }:

let
  cloudflareIps = config.services.cloudflare.ipv4 ++ config.services.cloudflare.ipv6;
  lanIps = [ "192.168.1.0/24" "127.0.0.1" "::1" ];
  
  # Helper to generate allow/deny for Cloudflare + LAN
  restrictionConfig = lib.concatMapStrings (ip: "allow ${ip};\n") (cloudflareIps ++ lanIps)
    + "deny all;";
in
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

  # Nginx Reverse Proxy (Private Domain only)
  services.nginx.virtualHosts."monitor.${config.server.privateDomain}" = {
    addSSL = false; # Private network only
    locations."/" = {
      proxyPass = "http://127.0.0.1:19999";
      proxyWebsockets = true;
      extraConfig = restrictionConfig;
    };
  };
}
