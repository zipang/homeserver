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
    mediaLocation = "/var/lib/immich";

    # The user to run the Immich service as.
    # user = "immich";

    # The group to run the Immich service as.
    # group = "immich";

    # Whether to open the firewall for the Immich port.
    # openFirewall = false;
    
    # Database configuration
    database = {
      # We enable the local database module even if we use a shared instance
      # because the Immich module needs to inject required PostgreSQL extensions 
      # (like pgvector) into the global services.postgresql configuration.
      enable = true;

      # Setting host to an absolute path forces the use of Unix sockets.
      host = "/run/postgresql";
    };

    # Redis configuration (using global shared Redis)
    redis = {
      # We disable the internal Redis server to use the centralized one.
      enable = false;

      # Point to the shared Unix socket.
      host = "/run/redis/redis.sock";
      port = 0; # Required to indicate unix socket usage
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
  services.nginx.virtualHosts."immich.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
    
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 0;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
        send_timeout 600s;

        # Authelia Protection
        auth_request /authelia;
        auth_request_set $target_url $scheme://$http_host$request_uri;
        error_page 401 = &https://auth.${config.server.privateDomain}/?rd=$target_url;
      '';
    };

    locations."/authelia" = {
      proxyPass = "http://127.0.0.1:9091/api/verify";
      extraConfig = ''
        internal;
        proxy_set_header Host auth.${config.server.privateDomain};
        proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
        proxy_set_header X-Forwarded-Method $request_method;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Uri $request_uri;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
      '';
    };
  };

  # Ensure the immich user can read the bind-mounted photos and access sockets
  users.users.immich.extraGroups = [ "zipang" "postgres" "redis" ];

  # Note: PostgreSQL ensureDatabases and ensureUsers for Immich are handled 
  # automatically by the module when services.immich.database.enable is true.
  
  # Add zipang to the immich group to manage the generated thumbnails/metadata if needed
  users.users.zipang.extraGroups = [ "immich" ];

  # Immich is sensitive to large uploads, ensure Nginx doesn't buffer them to disk too aggressively
  # services.nginx.commonHttpConfig = ''
  #   client_body_buffer_size 512k;
  # '';
}
