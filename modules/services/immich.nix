{ config, pkgs, ... }:

{
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    port = 2283;
    mediaLocation = "/var/lib/immich";
    
    # Database configuration (managed automatically by the module)
    database.enable = true;
    redis.enable = true;
  };

  # Configure Nginx for Immich
  services.nginx.virtualHosts."immich.example.com" = {
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

  # Immich is sensitive to large uploads, ensure Nginx doesn't buffer them to disk too aggressively
  # services.nginx.commonHttpConfig = ''
  #   client_body_buffer_size 512k;
  # '';
}
