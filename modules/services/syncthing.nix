{ config, pkgs, ... }:

{
  # Syncthing Service Configuration (NixOS 25.11)
  # Documentation: https://search.nixos.org/options?channel=25.11&query=services.syncthing
  services.syncthing = {
    enable = true;

    # Whether to create a systemd system service.
    # Default: true
    systemService = true;

    # User account under which Syncthing runs.
    # Default: "syncthing"
    user = "zipang";

    # Group under which Syncthing runs.
    # Default: "syncthing"
    group = "users";

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
    # Default: "127.0.0.1:8384" (localhost only)
    guiAddress = "127.0.0.1:8384";

    # Whether to open the default ports (22000/TCP/UDP, 21027/UDP).
    # Default: false
    openDefaultPorts = true;

    # Path to the certificate file.
    # Default: null (auto-generated in configDir)
    # cert = null;

    # Path to the key file.
    # Default: null (auto-generated in configDir)
    # key = null;

    # Extra command-line arguments passed to the syncthing binary.
    # NOTE: Syncthing v2.x removed the '--no-default-folder' flag.
    # If the service fails to start with "unknown flag", ensure it's not present here.
    extraFlags = [ "--no-browser" ];

    # Whether to delete the devices which are not configured via the devices option.
    # If set to false, devices added via the web interface will persist and will have to be deleted manually.
    # Default: true
    overrideDevices = false;

    # Whether to delete the folders which are not configured via the folders option.
    # If set to false, folders added via the web interface will persist and will have to be deleted manually.
    # Default: true
    overrideFolders = false;

    # Declarative configuration for devices, folders, and options.
    settings = {
      # List of devices to share folders with.
      devices = {
      };

      # List of folders to synchronize.
      folders = {
      };

      # Syncthing configuration options (config.xml)
      options = {
        # Whether to send announcements to the local LAN, also use such announcements to find other devices.
        localAnnounceEnabled = true;
        globalAnnounceEnabled = false;
        # When true, relays will be connected to and potentially used for device to device connections.
        relaysEnabled = false;
        # Usage reporting: -1 (no), 0 (not answered), >=1 (yes)
        urAccepted = -1;
      };

      # GUI settings
      gui = {
        # theme = "black";
        insecureSkipHostcheck = true; # Allow access via the reverse proxy domain
      };
    };
  };

  # Firewall rules
  # 8384: GUI
  # 22000: Syncing protocol
  # 21027: Local discovery
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  services.nginx.virtualHosts."syncthing.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:8384";
      proxyWebsockets = true;
    };
  };
}
