# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "SKYLAB"; # Define your hostname.

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  swapDevices = [{ device = "/dev/disk/by-label/SWAP"; }];

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "fr";
  #console = {
  #  font = "Lat2-Terminus32";
  #  keyMap = "fr";
  #  useXkbConfig = true; # use xkb.options in tty.
  #};

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.xkb.layout = "fr";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  # services.pipewire = {
  #   enable = true;
  #   pulse.enable = true;
  # };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a master user account. Don't forget to set a password with ‘passwd’.
  users.users.zipang = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [ ];
  };
  users.users.zipang.openssh.authorizedKeys.keyFiles = [
	/etc/nixos/ssh/authorized_keys
  ];

  users.users.master = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [ ];
  };
  users.users.master.openssh.authorizedKeys.keyFiles = [
	/etc/nixos/ssh/authorized_keys
  ];

  # Define the packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git		# Flakes clones its dependencies through the git command, so git must be installed first
    _7zz
    btop
    bun
    curl
    docker
    docker-compose
    fastfetch
    fd
    inetutils
    nano
    neovim
    nfs-utils
    openssh
    lsd
    lshw
    mpv
    pipx
    tree
    wget
  ];


  fileSystems."/home/zipang/Pictures" = {
	device = "/dev/disk/by-label/MEDIAS";
	fsType = "btrfs";
	options = [ "subvol=@pictures" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Documents" = {
        device = "/dev/disk/by-label/MEDIAS";
        fsType = "btrfs";
        options = [ "subvol=@documents" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Music" = {
        device = "/dev/disk/by-label/MEDIAS";
        fsType = "btrfs";
        options = [ "subvol=@music" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Games" = {
        device = "/dev/disk/by-label/MEDIAS";
        fsType = "btrfs";
        options = [ "subvol=@games" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Workspace" = {
        device = "/dev/disk/by-label/MEDIAS";
        fsType = "btrfs";
        options = [ "subvol=@workspace" "compress=zstd" "noatime" ];
  };
  
  # NFS shares
  fileSystems."/share/Skylab/Documents" = {
	device = "/dev/disk/by-label/MEDIAS";
	fsType = "btrfs";
	options = [ "subvolume=@documents" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Games" = {
	device = "/dev/disk/by-label/MEDIAS";
	fsType = "btrfs";
	options = [ "subvolume=@games" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Music" = {
	device = "/dev/disk/by-label/MEDIAS";
	fsType = "btrfs";
	options = [ "subvolume=@music" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Pictures" = {
	device = "/dev/disk/by-label/MEDIAS";
	fsType = "btrfs";
	options = [ "subvolume=@pictures" "compress=zstd" "noatime" "bind" ];
  };

  services.nfs.server = {
	enable = true;
	exports = ''
		/share			192.168.1.0/24(rw,fsid=0,no_subtree_check,crossmnt)
		/share/Skylab		192.168.1.0/24(rw,nohide,insecure,no_subtree_check)
 	'';
  };

  # Open port 2049 for NFS v4
  networking.firewall.allowedTCPPorts = [ 22 2049 ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:
  #services.immich = {
#	enable = true;
#	port = 2283;
#	host = "0.0.0.0"; # Makes it accessible on your network
#	mediaLocation = "/home/zipang/Pictures";
 # };

  #users.users.immich.extraGroups = ["video" "render"];

  # Enable the OpenSSH daemon.
  services.openssh = {
	enable = true;
	# require public key authentication for better security
	settings.PasswordAuthentication = false;
	settings.KbdInteractiveAuthentication = false;
	settings.PermitRootLogin = "no";
  };

  # Ban failed ssh attempts
  services.fail2ban = {
	enable = true;
	maxretry = 4;
	bantime = "-1";
	ignoreIP = [ "192.168.1.0/24" ];
  };

  # Enable docker
  virtualisation.docker.enable = true;

  # Enable NFS client support
  services.rpcbind.enable = true;

#  services.copyparty = {
#	enable = true;
#	# the user to run the service as
#	user = "copyparty"; 
#	# the group to run the service as
#	group = "copyparty"; 
#	# directly maps to values in the [global] section of the copyparty config.
#	# see `copyparty --help` for available options
#	settings = {
#		i = "0.0.0.0";
#		# use lists to set multiple values
#		p = [ 3210 3211 ];
#		# use booleans to set binary flags
#		no-reload = true;
#		# using 'false' will do nothing and omit the value when generating a config
#		ignored-flag = false;
#	};	
#
#	# create a volume
#	volumes = {
#		# create a volume at "/" (the webroot), which will
#		"/" = {
#			# share the contents of "/home/zipang"
#			path = "/share/Medias";
#			# see `copyparty --help-accounts` for available options
#			access = {
#				# zipang gets rw access
#				rw = [ "zipang" ];
#			};
#			# see `copyparty --help-flags` for available options
#			flags = {
#				# "fk" enables filekeys (necessary for upget permission) (4 chars long)
#				fk = 4;
#        			# scan for new files every 60sec
#				scan = 60;
#				# volflag "e2d" enables the uploads database
#				e2d = true;
#				# "d2t" disables multimedia parsers (in case the uploads are malicious)
#				d2t = true;
#				# skips hashing file contents if path matches *.iso
#				nohash = "\.iso$";
#			};
#		};
#	};
#
#	# you may increase the open file limit for the process
#	openFilesLimit = 8192;
#  };

  # Open ports in the firewall. (2049 is for NFS4 shares)
  # networking.firewall.allowedTCPPorts = [ 22 2049 ];
  # networking.firewall.allowedUDPPorts = [ 22 2049 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = true;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}

