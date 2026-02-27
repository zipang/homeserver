{ config, pkgs, lib, ... }:

let
  secretsFile = ./secrets.nix;
  secrets = if builtins.pathExists secretsFile
    then import secretsFile
    else builtins.throw "Mandatory file 'secrets.nix' not found in ${toString ./.}! Please create it from secrets.nix.example to provide your sensitive server details.";
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    # Modular system configurations
    ../../modules/system/options.nix
    ../../modules/system/boot.nix
    ../../modules/system/core.nix
    ../../modules/system/users.nix
    ../../modules/system/ssh.nix
    ../../modules/system/storage.nix
    ../../modules/system/sops.nix
    ../../modules/system/acme.nix

    # Programs
    ../../modules/programs/neovim.nix
    ../../modules/programs/media-tools.nix
    # ../../modules/programs/tmux.nix

    # Services
    ../../modules/services/nginx.nix
    ../../modules/services/fail2ban.nix
    ../../modules/services/docker.nix
    # ../../modules/services/samba.nix
    ../../modules/services/nfs.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/postgresql.nix
    ../../modules/services/redis.nix
    # ../../modules/services/authelia.nix
    ../../modules/services/pocketid.nix
    ../../modules/services/immich.nix
    ../../modules/services/jellyfin.nix
    # ../../modules/services/nextcloud.nix
    # ../../modules/services/copyparty.nix

  ];

  server = {
    hostName = "SKYLAB";
    publicDomain = secrets.publicDomain;
    privateDomain = secrets.privateDomain;
    adminEmail = secrets.adminEmail;
    mainUser = secrets.mainUser;
    timezone = "Europe/Paris";
    locale = "en_US.UTF-8";
  };

  networking.hostName = config.server.hostName;
  networking.hostId = "8425e349";

  # This value determines the NixOS release from which the default settings for stateful data,
  # like file locations and database versions on your system were taken.
  # Most users should never change this value after the initial install,
  # for any reason, even if you’ve upgraded your system to a new NixOS release.
  # This value does not affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will not upgrade your system.
  # This value being lower than the current NixOS release does not mean your system
  # is out of date, out of support, or vulnerable.
  system.stateVersion = "24.05"; # Did you read the comment?
}
