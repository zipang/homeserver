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
      root = ../../www;
      extraConfig = restrictionConfig;
    };
  };

  # Open ports for Nginx (internal traffic manager)
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
