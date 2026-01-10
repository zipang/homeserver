{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Optional: install docker-compose as a system package
  environment.systemPackages = [ pkgs.docker-compose ];
}
