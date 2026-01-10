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

  # Essential packages for the system (migrated from reference)
  environment.systemPackages = with pkgs; [
    git
    _7zz
    btop
    bun
    curl
    docker
    docker-compose
    fastfetch
    fd
    inetutils
    nano
    neovim
    nfs-utils
    openssh
    lsd
    lshw
    mpv
    pipx
    tree
    wget
    htop # Added back from original core.nix
  ];

  # Basic networking
  networking.networkmanager.enable = true;
}
