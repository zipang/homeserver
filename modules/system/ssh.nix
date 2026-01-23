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

  # Firewall: only allow SSH (other ports handled by respective modules)
  networking.firewall.allowedTCPPorts = [ 22 ];
}
