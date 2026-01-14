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

  # Ban failed external ssh attempts
  services.fail2ban = {
    enable = true;
    maxretry = 4;
    bantime = "-1"; # Permanent ban
    ignoreIP = [ "192.168.1.0/24" ]; # local network
  };

  # Firewall: only allow SSH (other ports handled by respective modules)
  networking.firewall.allowedTCPPorts = [ 22 ];
}
