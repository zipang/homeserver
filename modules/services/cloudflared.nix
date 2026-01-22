{ config, pkgs, ... }:

{
  services.cloudflared = {
    enable = true;
    tunnels = {
      # The tunnel configuration
      "homeserver" = {
        # The tunnel ID secret from sops
        tunnel = "REPLACE_WITH_TUNNEL_ID_OR_REFERENCE_SECRET"; 
        credentialsFile = config.sops.secrets."cloudflared/credentials".path;
        
        # Ingress rules: map public domains to local Nginx
        ingress = {
          # We point everything to Nginx, which then routes to the specific service
          "immich.example.com" = "http://localhost:80"; 
          # Default rule: if no match, return 404
          "*" = "http_status:404";
        };
        
        default = "http_status:404";
      };
    };
  };
}
