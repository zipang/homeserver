{ config, pkgs, lib, ... }:

  let
    cfg = config.services.netbird;
  in
  {
    options.services.netbird = {
      enable = lib.mkEnableOption "Netbird VPN service (can act as a server or client)";
      serverUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://netbird.example.com:8443"; # Placeholder: Replace with your actual Control Plane URL
        description = "The URL of the Netbird Control Plane server.";
      };
    };

    config = lib.mkIf cfg.enable {
      # 1. Install the Netbird package
      environment.systemPackages = [ pkgs.netbird ];

      # 2. Configure the Netbird systemd service which often manages client/server daemon
      services.netbird = {
        enable = true;
        serverUrl = cfg.serverUrl; # Crucial for both roles to know where the control plane is
      };

      # 3. Explicitly enable the systemd client management service, common for hosts.
      # This ensures 'netbird up' / 'netbird down' functionality is available and managed.
      systemd.netbird.enable = lib.mkDefault true;
    };
  }
