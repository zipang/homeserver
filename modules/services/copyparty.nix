{ config, pkgs, ... }:

{
  services.copyparty = {
    enable = true;
    user = "zipang";
    group = "users";

    settings = {
      i = "0.0.0.0";
      p = 3923;
    };

    accounts.zipang.passwordFile = "/etc/nixos/secrets/copyparty_zipang";

    volumes = {
      "/" = {
        path = "/home/zipang";
        access = {
          r = "*";
          rw = [ "zipang" ];
        };
        flags = {
          e2d = true;
          scan = 60;
        };
      };
    };
  };

  # Port for copyparty web service
  networking.firewall.allowedTCPPorts = [ 3923 ];
}
