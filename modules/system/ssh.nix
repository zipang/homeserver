{ config, pkgs, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Firewall: only allow SSH by default (NFS module will open its own)
  networking.firewall.allowedTCPPorts = [ 22 ];
}
