{ config, pkgs, ... }:

{
  services.copyparty = {
    enable = true;
    # Run as the main user so received files land with normal ownership
    user = "zipang";
    group = "users";

    settings = {
      # Bind to loopback only: LAN traffic goes through the Nginx TLS proxy
      i = "127.0.0.1";
      p = 3923;
      # Keep the module defaults (types.attrs replaces them otherwise)
      no-reload = true;
      hist = "/var/cache/copyparty";
    };

    # No accounts: there is no password authentication on this service.
    #
    # No volume is mounted at "/" so copyparty serves a picker page listing
    # the available volumes; every volume is anonymous upload-only (w), so
    # LAN visitors can drop files but never list or read them back.
    # App-level assets (/.cpr/...) are served by the Nginx full proxy below.
    volumes = {
      "/buzz" = {
        path = "/share/Storage/BUZZ";
        access = {
          w = "*";
        };
      };

      "/photos" = {
        path = "/share/Storage/WOODY/photos";
        access = {
          w = "*";
        };
      };
    };
  };

  # The USB pools are mounted with 'nofail' + automount, and the upstream
  # systemd unit bind-mounts every volume path, which fails to start if a
  # pool is not mounted yet. Require the mounts instead.
  systemd.services.copyparty.unitConfig.RequiresMountsFor = [
    "/share/Storage/BUZZ"
    "/share/Storage/WOODY/photos"
  ];

  # Nginx TLS reverse proxy: full proxy per upstream recommendation
  # (contrib/nginx/copyparty.conf). File exposure stays controlled by the
  # copyparty volumes themselves (upload-only, no root volume).
  services.nginx.virtualHosts."copyparty.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:3923";
      proxyWebsockets = true;
      extraConfig = ''
        # Recommended by upstream for fast uploads/downloads
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_buffers 32 8k;
        proxy_buffer_size 16k;
        proxy_busy_buffers_size 24k;
      '';
    };
  };
}
