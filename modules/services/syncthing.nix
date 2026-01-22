{ config, pkgs, ... }:

{
  services.syncthing.extraFlags = [ "--no-default-folder" ]; # Don't create default ~/Sync folder
  services.syncthing = {
    enable = true;
    user = "zipang";
    group = "users";
    dataDir = "/home/zipang";
    configDir = "/home/zipang/.config/syncthing";
    guiAddress = "127.0.0.1:8384";

    overrideDevices = true;     # overrides any devices added or deleted through the WebUI
    overrideFolders = true;     # overrides any folders added or deleted through the WebUI
    settings = {
      devices = {
        "SKYLAB" = { id = "PZLQNYP-IJQWCEN-ZJK3RKF-SYHSJVG-BFSPTTN-AJAZ7LS-77TXJ53-WOV5GQC"; };
        "FEDORA-WORKSTATION" = { id = "NACG2PA-YIYCXOE-VALUJVR-EC7NOD5-NHGKRET-TLVPG3M-X7IIBJZ-F6XFZQH"; };
      };
      folders = {
        "documents" = {         # Name of folder in Syncthing, also the folder ID
          path = "/home/zipang/Documents";    # Which folder to add to Syncthing
          devices = [ "SKYLAB" "FEDORA-WORKSTATION" ];      # Which devices to share the folder with
        };
        "workspace" = {
          path = "/home/zipang/Workspace";
          devices = [ "SKYLAB" ];
          ignorePerms = false;  # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
        };
      };
    };

    # Open firewall ports
    # 22000 TCP/UDP for sync, 21027 UDP for discovery
    openDefaultPorts = true;
  };

  # Optional: specific firewall rules if openDefaultPorts wasn't enough or for clarity
  networking.firewall.allowedTCPPorts = [ 8384 ]; # Only if you want GUI over LAN without tunnel
}
