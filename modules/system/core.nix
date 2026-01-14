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


    # Custom update script
    (writeShellScriptBin "update-nix" ''
      set -e
      BRANCH=''${1:-master}
      echo "🚀 Starting SKYLAB System Update (Branch: $BRANCH)..."

      echo "🔧 [0/4] Fixing repository permissions..."
      cd /home/master/homeserver
      # Ensure current user owns the directory to avoid git permission errors
      sudo chown -R $USER:wheel .

      echo "📥 [1/4] Pulling latest changes from Git..."
      git fetch origin
      git checkout "$BRANCH"
      git pull origin "$BRANCH"

      echo "🔄 [2/4] Updating Flake lockfile..."
      nix flake update

      echo "⚒️  [3/4] Rebuilding NixOS system..."
      sudo nixos-rebuild switch --impure --flake .#SKYLAB

      echo "📝 [4/4] Checking for lockfile changes..."
      if ! git diff --quiet flake.lock; then
        echo "📤 Pushing updated flake.lock to repository..."
        git add flake.lock
        git commit -m "chore: update flake.lock after system upgrade"
        git push origin "$BRANCH"
      else
        echo "✅ No changes to flake.lock. System is up to date."
      fi

      echo "✨ Update complete!"
    '')
  ];

  # Basic networking
  networking.networkmanager.enable = true;

  # Path configuration for management scripts
  environment.sessionVariables = {
    PATH = [ "$PATH:/home/master/homeserver/scripts" ];
  };

  environment.shellAliases = {
    ls = "lsd";
    la = "lsd -la";
    ll = "lsd -l";
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
