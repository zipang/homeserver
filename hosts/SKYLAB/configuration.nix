{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Modular system configurations
    ../../modules/system/boot.nix
    ../../modules/system/core.nix
    ../../modules/system/users.nix
    ../../modules/system/ssh.nix
    ../../modules/system/storage.nix
    ../../modules/system/sops.nix

    # Programs
    ../../modules/programs/neovim.nix
    ../../modules/programs/tmux.nix

    # Services
    ../../modules/services/nginx.nix
    ../../modules/services/fail2ban.nix
    ../../modules/services/docker.nix
    # ../../modules/services/samba.nix
    ../../modules/services/nfs.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/immich.nix
    ../../modules/services/authelia.nix
    # ../../modules/services/copyparty.nix
  ];

  networking.hostName = "SKYLAB";
  networking.hostId = "8425e349";

  # ZFS Services
  boot.zfs.extraPools = [ "BUZZ" "WOODY" ];
  services.zfs.autoScrub.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
