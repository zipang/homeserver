{ config, pkgs, ... }:

{
  time.timeZone = "Europe/Paris"; # Adjusted for your probable location, please verify
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.homelab = {
    isNormalUser = true;
    description = "Homelab Administrator";
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    # Password should be set via 'passwd' on the machine or via hashed password
  };

  # Essential packages for the system
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    htop
    btop
    tree
  ];

  # Basic networking
  networking.networkmanager.enable = true;
}
