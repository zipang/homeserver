{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    
    # Optimizations for a home server
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Default client_max_body_size is 1m, which is too small for photos/videos.
    # We set a large default, but will override it specifically for Immich.
    clientMaxBodySize = "10G";

    # Virtual Hosts will be added as we implement services
    virtualHosts."syncthing.skylab.local" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true;
      };
    };
  };

  # Open ports for Nginx (internal traffic manager)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
