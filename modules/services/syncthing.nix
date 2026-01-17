{ config, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    user = "zipang";
    dataDir = "/home/zipang";
    configDir = "/home/zipang/.config/syncthing";
    guiAddress = "127.0.0.1:8384";

    # Open firewall ports
    # 22000 TCP/UDP for sync, 21027 UDP for discovery
    openDefaultPorts = true;
  };

  # Optional: specific firewall rules if openDefaultPorts wasn't enough or for clarity
  # networking.firewall.allowedTCPPorts = [ 8384 ]; # Only if you want GUI over LAN without tunnel
}
