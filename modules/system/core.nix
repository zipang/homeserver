{ config, pkgs, pkgs-unstable, ... }:

{

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Optimization settings
  nix.settings.auto-optimise-store = true;

  # Nix < 2.33 warns when a single download consumer cannot keep up with the
  # 64 MiB default buffer during large substitutions ("download buffer is
  # full"). 500 MiB is the community-validated value for fast connections.
  # (Fixed upstream in Nix 2.33 - this line can be dropped after upgrading.)
  nix.settings.download-buffer-size = 524288000; # 500 MiB

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
    # Bun is a fast-moving runtime and nixos-25.11 lags behind upstream, so it
    # comes from the unstable package set (already used by the agent module).
    # NOTE: `bun upgrade` can never work here - the binary lives in the
    # read-only Nix store. Upgrade with `update-nix` instead. See docs/bun.md.
    pkgs-unstable.bun
    curl
    devbox
    docker_29
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
    # 0755 root:root so nginx can traverse to skylab.key (0640 root:nginx) and
    # normal users can scp the public skylab-ca.crt (0444); private keys inside
    # are mode-restricted (skylab-ca.key is 0400 root:root).
    "z /var/lib/secrets/certs 0755 root root -"
    "d /var/lib/secrets/certs 0755 root root -"
    "d /var/lib/secrets/ssh 0755 root root -"
    "d /var/lib/secrets/sso 0700 root root -"
  ];

}
