{ config, pkgs, lib, ... }:

let
  # Users whose ~/.ssh must always belong to them (deduplicated: mainUser is
  # usually "zipang" as well).
  sshUsers = lib.unique [ "zipang" config.server.mainUser ];
in
{
  # Define users
  users.users.zipang = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
  };

  # Tie git to user zipang
  programs.git = {
    enable = true;
    config = {
      user.name = "zipang";
      user.email = "christophe.desguez@gmail.com";
      init.defaultBranch = "master";
      safe.directory = "/home/${config.server.mainUser}/homeserver";
    };
  };

  users.users."${config.server.mainUser}" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
  };

  # ---------------------------------------------------------------------------
  # ~/.ssh ownership guard
  #
  # NixOS creates $HOME (mode 0700, owner = the user) but deliberately never
  # touches $HOME/.ssh: authorized keys are read from /etc/ssh/authorized_keys.d
  # instead. As a result, the first command run as root that needs an SSH
  # client (`sudo ssh ...`, `sudo git clone git@...`, or a `sudo -i` shell)
  # creates /home/<user>/.ssh as root:root 0700. From then on, every ssh/git
  # call made as the user fails with:
  #
  #   hostkeys_find_by_key_hostfile: hostkeys_foreach failed for
  #   /home/<user>/.ssh/known_hosts: Permission denied
  #
  # These tmpfiles rules re-assert the correct ownership at every boot, so the
  # damage is self-healing instead of requiring a manual chown:
  #   Z → recursively chown the whole ~/.ssh tree to the user (mode "-" keeps
  #       existing file modes, so private keys are never loosened)
  #   d → force the directory itself back to 0700
  # ---------------------------------------------------------------------------
  systemd.tmpfiles.rules =
    lib.concatMap (user: [
      "Z /home/${user}/.ssh - ${user} users -"
      "d /home/${user}/.ssh 0700 ${user} users -"
    ])
      sshUsers;

  # Add scripts/ directory to the path
  environment.sessionVariables = {
    PATH = [ "$PATH:/home/${config.server.mainUser}/homeserver/scripts" ];
  };

  environment.shellAliases = {
    ls = "lsd";
    la = "lsd -la";
    ll = "lsd -l";
  };

  programs.starship.enable = true;

}
