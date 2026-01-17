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
    lsd
    lshw
    mpv
    sops
    tree
    wget
  ];

  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = 10000;
    extraConfig = ''
      # Enable mouse support
      set -g mouse on

      # Split panes using | and -
      bind | split-window -h
      bind - split-window -v
      unbind '"'
      unbind %

      # Switch panes using Alt-arrow without prefix
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Kill window with X
      bind X kill-window

      # Reload config with r
      bind r source-file /etc/tmux.conf \; display "Reloaded!"
    '';
  };

}
