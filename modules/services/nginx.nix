{ config, pkgs, lib, ... }:

let
  cloudflareIps = config.services.cloudflare.ipv4 ++ config.services.cloudflare.ipv6;
  lanIps = [ "192.168.1.0/24" "127.0.0.1" "::1" ];
  
  # Helper to generate allow/deny for Cloudflare + LAN
  restrictionConfig = lib.concatMapStrings (ip: "allow ${ip};\n") (cloudflareIps ++ lanIps)
    + "deny all;";
in
{
  imports = [
    ./cloudflare-ips.nix
  ];

  services.cloudflare.enable = true;

  services.nginx = {
    enable = true;

    # Trust Cloudflare IPs to get real client IPs in logs
    commonHttpConfig = lib.concatMapStrings (ip: "set_real_ip_from ${ip};\n") cloudflareIps
      + "real_ip_header CF-Connecting-IP;";

    # Optimizations for a home server
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Default client_max_body_size is 1m, which is too small for photos/videos.
    # We set a large default, but will override it specifically for Immich.
    clientMaxBodySize = "10G";

    # Virtual Hosts will be added as we implement services
    virtualHosts."${config.server.publicDomain}" = {
      forceSSL = true;
      useACMEHost = config.server.publicDomain;
      # Path to the static content, baked into the Nix store
      root = ../../www;
      
      # Apply Cloudflare + LAN restriction to the public domain
      extraConfig = restrictionConfig;
    };

    virtualHosts."syncthing.${config.server.privateDomain}" = {
      forceSSL = true;
      sslCertificate = "/var/lib/secrets/certs/skylab.crt";
      sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true;
      };
    };

    virtualHosts."pocketid.${config.server.privateDomain}" = {
      forceSSL = true;
      sslCertificate = "/var/lib/secrets/certs/skylab.crt";
      sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

      # SvelteKit (used by Pocketid) generates large headers
      # These buffer settings are required to avoid "431 Request Header Fields Too Large" errors
      extraConfig = ''
        proxy_busy_buffers_size 512k;
        proxy_buffers 4 512k;
        proxy_buffer_size 256k;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:1411";
        proxyWebsockets = true;

        # Pass the X-Forwarded headers so Pocketid knows the real client IP and protocol
        extraConfig = ''
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  # Open ports for Nginx (internal traffic manager)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
