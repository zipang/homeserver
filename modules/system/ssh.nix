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

  # Ban failed ssh attempts (migrated from reference)
  services.fail2ban = {
    enable = true;
    maxretry = 4;
    bantime = "-1"; # Permanent ban as per reference
    ignoreIP = [ "192.168.1.0/24" ];
  };

  # Firewall: only allow SSH and NFS (NFS module will handle 2049)
  networking.firewall.allowedTCPPorts = [ 22 2049 ];
}
