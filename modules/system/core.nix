{ config, pkgs, ... }:

{
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "fr";

  # Define users
  users.users.zipang = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    openssh.authorizedKeys.keyFiles = [ /etc/nixos/ssh/authorized_keys ];
  };

  users.users.master = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    openssh.authorizedKeys.keyFiles = [ /etc/nixos/ssh/authorized_keys ];
  };

  # Swap configuration from reference
  swapDevices = [{ device = "/dev/disk/by-label/SWAP"; }];

  # Essential packages for the system
  environment.systemPackages = with pkgs; [
    _7zz
    btop
    bun
    curl
    docker
    docker-compose
    fastfetch
    fd
    git
    inetutils
    nano
    nfs-utils
    openssh
    lsd
    lshw
    mpv
    tree
    wget
  ];

  # Basic networking
  networking.networkmanager.enable = true;

  environment.shellAliases = {
    ls = "lsd";
    la = "lsd -la";
    ll = "lsd -l";
    update-nix = "cd /home/master/homeserver && git pull && nix flake update && sudo nixos-rebuild switch --impure --flake .#SKYLAB";
  };

  programs.starship.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    config = {
      user.name = "zipang";
      user.email = "christophe.desguez@gmail.com";
      init.defaultBranch = "master";
      safe.directory = "/home/master/homeserver";
    };
  };
}
