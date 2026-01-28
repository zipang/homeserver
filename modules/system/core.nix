{ config, pkgs, ... }:

{

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optimization settings
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "fr";

  # Basic networking
  networking.networkmanager.enable = true;

  # Swap configuration from reference
  swapDevices = [{ device = "/dev/disk/by-label/SWAP"; }];

  # Essential packages for the system
  environment.systemPackages = with pkgs; [
    git  # Note: git must be put first because Flakes
    _7zz
    age
    btop
    bun
    curl
    docker
    docker-compose
    fastfetch
    fd
    inetutils
    nano
    nfs-utils
    openssh
    openssl
    ssh-to-age
    lsd
    lshw
    mkcert
    mpv
    sops
    tree
    unzip
    wget
  ];
  
  # Ensure persistent directories for manual secrets (like SSL certs)
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets 0755 root root -"
    "d /var/lib/secrets/certs 0700 nginx nginx -"
    "d /var/lib/secrets/ssh 0755 root root -"
    "d /var/lib/secrets/sso 0700 root root -"
  ];

}
