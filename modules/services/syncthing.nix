{ config, pkgs, ... }:

{
  # Syncthing Service Configuration (NixOS 25.11)
  # Documentation: https://search.nixos.org/options?channel=25.11&query=services.syncthing
  services.syncthing = {
    enable = true;

    # The Syncthing package to use. 
    # Default: pkgs.syncthing
    package = pkgs.syncthing;

    # Whether to create a systemd system service.
    # Default: true
    systemService = true;

    # User account under which Syncthing runs.
    # Default: "syncthing"
    user = "zipang";

    # Group under which Syncthing runs.
    # Default: "syncthing"
    group = "users";

    # The hostname to use for the local device.
    # Default: config.networking.hostName
    hostname = "SKYLAB";

    # The path where synchronized folders are stored by default.
    # Default: "/var/lib/syncthing"
    dataDir = "/home/zipang";

    # The directory where configuration and keys are stored.
    # Default: config.services.syncthing.dataDir
    configDir = "/home/zipang/.config/syncthing";

    # The directory where the database is stored.
    # Default: config.services.syncthing.configDir
    databaseDir = "/home/zipang/.config/syncthing";

    # The address the web interface will listen on.
    # Default: "127.0.0.1:8384"
    guiAddress = "127.0.0.1:8384";

    # Whether to open the default ports (22000/TCP/UDP, 21027/UDP).
    # Default: false
    openDefaultPorts = false;

    # Path to the certificate file.
    # Default: null (auto-generated in configDir)
    cert = null;

    # Path to the key file.
    # Default: null (auto-generated in configDir)
    key = null;

    # Extra command-line arguments passed to the syncthing binary.
    # NOTE: Syncthing v2.x removed the '--no-default-folder' flag. 
    # If the service fails to start with "unknown flag", ensure it's not present here.
    extraArgs = [ ];

    # Whether to overwrite devices configured in the WebUI with these settings.
    # Default: true
    overrideDevices = true;

    # Whether to overwrite folders configured in the WebUI with these settings.
    # Default: true
    overrideFolders = true;

    # Declarative configuration for devices, folders, and options.
    settings = {
      # List of devices to share folders with.
      devices = {
        "SKYLAB" = { id = "PZLQNYP-IJQWCEN-ZJK3RKF-SYHSJVG-BFSPTTN-AJAZ7LS-77TXJ53-WOV5GQC"; };
        "FEDORA-WORKSTATION" = { id = "NACG2PA-YIYCXOE-VALUJVR-EC7NOD5-NHGKRET-TLVPG3M-X7IIBJZ-F6XFZQH"; };
      };

      # List of folders to synchronize.
      folders = {
        "documents" = {
          path = "/home/zipang/Documents";
          devices = [ "SKYLAB" "FEDORA-WORKSTATION" ];
          # Whether to ignore file permissions.
          ignorePerms = false;
        };
        "workspace" = {
          path = "/home/zipang/Workspace";
          devices = [ "SKYLAB" ];
          ignorePerms = false;
        };
      };

      # Syncthing configuration options (config.xml)
      options = {
        # Usage reporting: -1 (ask), 0 (no), 1 (yes)
        # urAccepted = -1;
        # localAnnounceEnabled = true;
      };

      # GUI settings
      gui = {
        # theme = "black";
      };
    };
  };

  # Firewall rules
  # 8384: GUI (only for SSH tunnel or local access)
  # 22000: Syncing protocol
  # 21027: Local discovery
  networking.firewall.allowedTCPPorts = [ 8384 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];
}
