{ config, pkgs, ... }:

{
  services.copyparty = {
    enable = true;
    # Run as the main user so received files land with normal ownership
    user = "zipang";
    group = "users";

    settings = {
      # Bind to loopback only:
      # - LAN traffic goes through the Nginx TLS proxy (drop boxes only)
      # - the full UI is reached via SSH tunnel (ssh -L 3923:...)
      i = "127.0.0.1";
      p = 3923;
      # Keep the module defaults (types.attrs replaces them otherwise)
      no-reload = true;
      hist = "/var/cache/copyparty";
    };

    # No accounts: there is no password authentication on this service.
    # - "/drop/*" volumes are anonymous upload-only (w), exposed on the LAN
    #   through Nginx - senders can never list or download what they dropped.
    # - "/" (browse) is only reachable through an SSH tunnel, which is
    #   authenticated by SSH keys (PasswordAuthentication = false in ssh.nix).
    volumes = {
      "/" = {
        path = "/share";
        access = {
          r = "*";
        };
      };

      "/drop/buzz" = {
        path = "/share/Storage/BUZZ";
        access = {
          w = "*";
        };
      };

      "/drop/photos" = {
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

  # Nginx TLS reverse proxy: anonymous drop boxes for the local network.
  # Only /drop/* is exposed; the root volume and the admin UI are NOT.
  services.nginx.virtualHosts."copyparty.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    # Everything except /drop/* stays LAN-private (use the SSH tunnel)
    locations."/" = {
      extraConfig = ''
        deny all;
      '';
    };

    locations."/drop/" = {
      proxyPass = "http://127.0.0.1:3923";
      proxyWebsockets = true;
    };
  };
}
