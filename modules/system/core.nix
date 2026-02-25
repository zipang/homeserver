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

  time.timeZone = config.server.timezone;
  i18n.defaultLocale = config.server.locale;
  console.keyMap = "fr";

  # Basic networking
  networking.networkmanager.enable = true;

  # Bluetooth support
  hardware.bluetooth.enable = true;

  # Swap configuration from reference
  swapDevices = [{ device = "/dev/disk/by-label/SWAP"; }];

  # Essential packages for the systemeekbench
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    git  # Note: git must be put first because Flakes
    _7zz
    age
    broot
    btop
    bluetui
    curl
    devbox
    docker
    docker-compose
    fastfetch
    fd
    fatrace
    geekbench
    inetutils
    iotop
    lsof
    mc
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
