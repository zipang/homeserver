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
    # virtualHosts."auth.skylab.local" = {
    #   forceSSL = true;
    #   sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    #   sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
    #   locations."/" = {
    #     proxyPass = "http://127.0.0.1:9091";
    #     proxyWebsockets = true;
    #   };
    # };

    virtualHosts."syncthing.skylab.local" = {
      forceSSL = true;
      sslCertificate = "/var/lib/secrets/certs/skylab.crt";
      sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
      
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true;
        # extraConfig = ''
        #   auth_request /authelia;
        #   auth_request_set $target_url $scheme://$http_host$request_uri;
        #   error_page 401 = &https://auth.skylab.local/?rd=$target_url;
        #   
        #   # Pass user information to the backend
        #   auth_request_set $user $upstream_http_remote_user;
        #   auth_request_set $groups $upstream_http_remote_groups;
        #   auth_request_set $name $upstream_http_remote_name;
        #   auth_request_set $email $upstream_http_remote_email;
        #   proxy_set_header Remote-User $user;
        #   proxy_set_header Remote-Groups $groups;
        #   proxy_set_header Remote-Name $name;
        #   proxy_set_header Remote-Email $email;
        # '';
      };

      # locations."/authelia" = {
      #   proxyPass = "http://127.0.0.1:9091/api/verify";
      #   extraConfig = ''
      #     internal;
      #     proxy_set_header Host auth.skylab.local;
      #     proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
      #     proxy_set_header X-Forwarded-Method $request_method;
      #     proxy_set_header X-Forwarded-Proto $scheme;
      #     proxy_set_header X-Forwarded-Host $http_host;
      #     proxy_set_header X-Forwarded-Uri $request_uri;
      #     proxy_set_header X-Forwarded-For $remote_addr;
      #     proxy_pass_request_body off;
      #     proxy_set_header Content-Length "";
      #   '';
      # };
    };
  };

  # Open ports for Nginx (internal traffic manager)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
