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
    mediaLocation = "/share/External/WOODY/photos";

    # The user to run the Immich service as.
    # user = "immich";

    # The group to run the Immich service as.
    # group = "immich";

    # Whether to open the firewall for the Immich port.
    # openFirewall = false;
    
    # Database configuration (managed automatically by the module)
    database = {
      # Whether to enable the local PostgreSQL database.
      enable = true;

      # The host of the PostgreSQL database.
      # host = "localhost";

      # The port of the PostgreSQL database.
      # port = 5432;

      # The name of the PostgreSQL database.
      # name = "immich";

      # The user of the PostgreSQL database.
      # user = "immich";
    };

    # Redis configuration (managed automatically by the module)
    redis = {
      # Whether to enable the local Redis instance.
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

  # Immich is sensitive to large uploads, ensure Nginx doesn't buffer them to disk too aggressively
  # services.nginx.commonHttpConfig = ''
  #   client_body_buffer_size 512k;
  # '';
}
