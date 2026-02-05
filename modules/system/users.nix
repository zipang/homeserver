{ config, pkgs, ... }:

{
  # Define users
  users.users.zipang = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
  };

  # Tie git to user zipang
  programs.git = {
    enable = true;
    config = {
      user.name = "zipang";
      user.email = "christophe.desguez@gmail.com";
      init.defaultBranch = "master";
      safe.directory = "/home/master/homeserver";
    };
  };

  users.users.master = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
  };

  # zrok system user for container management
  users.users.zrok = {
    uid = 2171;
    group = "zrok";
    isSystemUser = true;
  };

  users.groups.zrok = {
    gid = 2171;
  };

  # Add scripts/ directory to the path
  environment.sessionVariables = {
    PATH = [ "$PATH:/home/master/homeserver/scripts" ];
  };

  environment.shellAliases = {
    ls = "lsd";
    la = "lsd -la";
    ll = "lsd -l";
  };

  programs.starship.enable = true;

}
