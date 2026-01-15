{ config, pkgs, ... }:

let
  mediasDevice = "/dev/disk/by-label/MEDIAS";
in
{
  # --- 1. Mount BTRFS Subvolumes (Local user mounts) ---
  fileSystems."/home/zipang/Pictures" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@pictures" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Documents" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@documents" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Music" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@music" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Games" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@games" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Workspace" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@workspace" "compress=zstd" "noatime" ];
  };

  # --- 2. Share Tree (Common mount point for sharing services) ---
  # We bind mount existing user directories under /share/Skylab for external access.
  # This avoids race conditions on BTRFS subvolumes and ensures the system boots
  # even if there's an issue with the shares (nofail).
  fileSystems."/share/Skylab/Documents" = {
    device = "/home/zipang/Documents";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home/zipang/Documents" ];
  };

  fileSystems."/share/Skylab/Games" = {
    device = "/home/zipang/Games";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home/zipang/Games" ];
  };

  fileSystems."/share/Skylab/Music" = {
    device = "/home/zipang/Music";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home/zipang/Music" ];
  };

  fileSystems."/share/Skylab/Pictures" = {
    device = "/home/zipang/Pictures";
    fsType = "none";
    options = [ "bind" "nofail" "x-systemd.requires-mounts-for=/home/zipang/Pictures" ];
  };

  # Ensure the mount points exist
  systemd.tmpfiles.rules = [
    "d /share 0755 root root -"
    "d /share/Skylab 0755 root root -"
    "d /share/Skylab/Documents 0755 root root -"
    "d /share/Skylab/Games 0755 root root -"
    "d /share/Skylab/Music 0755 root root -"
    "d /share/Skylab/Pictures 0755 root root -"
  ];
}
