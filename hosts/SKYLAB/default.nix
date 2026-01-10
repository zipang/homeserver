{ config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    # This file will be copied from /etc/nixos/hardware-configuration.nix on the host.
    ./hardware.nix

    # Modular system configurations
    ../../modules/system/core.nix
    ../../modules/system/ssh.nix
    ../../modules/system/nix-settings.nix
    
    # Services
    ../../modules/services/nfs.nix
    ../../modules/services/docker.nix
  ];

  networking.hostName = "SKYLAB";

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
