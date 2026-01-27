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

  # SSH Keys management
  # We use a persistent path for authorized_keys to keep them out of Git
  users.users.zipang.openssh.authorizedKeys.keyFiles = [ /var/lib/secrets/ssh/authorized_keys ];
  users.users.master.openssh.authorizedKeys.keyFiles = [ /var/lib/secrets/ssh/authorized_keys ];

  # Firewall: only allow SSH (other ports handled by respective modules)
  networking.firewall.allowedTCPPorts = [ 22 ];
}
