{ config, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    # Docker 28 is unmaintained and marked insecure in nixpkgs 25.11;
    # pin the current stable release explicitly
    package = pkgs.docker_29;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Optional: install docker-compose as a system package
  environment.systemPackages = [ pkgs.docker-compose ];
}
