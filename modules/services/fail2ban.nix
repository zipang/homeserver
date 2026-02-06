{ config, pkgs, ... }:

{
  # Fail2Ban Service Configuration
  # Documentation: https://search.nixos.org/options?channel=25.11&query=services.fail2ban
  services.fail2ban = {
    enable = true;
    
    # Global settings
    maxretry = 5;
    bantime = "-1"; # Permanent ban
    
    # Do not ban our local network
    ignoreIP = [
      "127.0.0.1/8"
      "::1/128"
      "192.168.1.0/24"
    ];

    # Custom filters
    # These match patterns in logs to trigger bans
    filters = {
      nginx-forbidden = {
        settings = {
          # Match lines where Nginx returns a 403 Forbidden
          # This happens when someone bypasses Cloudflare to hit your public IP
          failregex = ''^<HOST> - .* "(GET|POST|HEAD) .* HTTP/.*" 403 .*$'';
        };
      };
    };

    # Extra configuration to catch Nginx Forbidden errors (403) from non-Cloudflare IPs
    # This will ban scanners trying to hit your public IP directly
    jails = {
      nginx-forbidden = {
        settings = {
          enabled = true;
          port = "http,https";
          filter = "nginx-forbidden";
          logpath = "/var/log/nginx/access.log";
          maxretry = 2;
        };
      };

      # SSH protection (already covered by services.fail2ban.enable = true usually, 
      # but we explicitly define parameters for clarity)
      sshd = {
        settings = {
          enabled = true;
          port = "ssh";
          filter = "sshd";
          maxretry = 3;
        };
      };

      # Nginx protections
      nginx-http-auth = {
        settings = {
          enabled = true;
          port = "http,https";
          filter = "nginx-http-auth";
          logpath = "/var/log/nginx/error.log";
        };
      };

      nginx-botsearch = {
        settings = {
          enabled = true;
          port = "http,https";
          filter = "nginx-botsearch";
          logpath = "/var/log/nginx/error.log";
          maxretry = 2;
        };
      };

      nginx-bad-request = {
        settings = {
          enabled = true;
          port = "http,https";
          filter = "nginx-bad-request";
          logpath = "/var/log/nginx/error.log";
          maxretry = 3;
        };
      };
    };
  };
}
