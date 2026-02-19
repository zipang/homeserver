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
      safe.directory = "/home/${config.server.mainUser}/homeserver";
    };
  };

  users.users."${config.server.mainUser}" = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
  };



  # Add scripts/ directory to the path
  environment.sessionVariables = {
    PATH = [ "$PATH:/home/${config.server.mainUser}/homeserver/scripts" ];
  };

  environment.shellAliases = {
    ls = "lsd";
    la = "lsd -la";
    ll = "lsd -l";
  };

  programs.starship.enable = true;

}
