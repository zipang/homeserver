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
  # We use bind mounts to expose user directories under /share/Skylab.
  # Using fileSystems is more idiomatic for NixOS and handles unit generation.
  fileSystems."/share/Skylab/Documents" = {
    device = "/home/zipang/Documents";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/share/Skylab/Games" = {
    device = "/home/zipang/Games";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/share/Skylab/Music" = {
    device = "/home/zipang/Music";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/share/Skylab/Pictures" = {
    device = "/home/zipang/Pictures";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  fileSystems."/share/Skylab/Workspace" = {
    device = "/home/zipang/Workspace";
    fsType = "none";
    options = [ "bind" "nofail" ];
  };

  # --- 3. Shared ZFS External Pools ---
  fileSystems."/share/External/BUZZ" = {
    device = "BUZZ";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" ];
  };

  fileSystems."/share/External/WOODY" = {
    device = "WOODY";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" ];
  };

  # Ensure only the parent directory exists
  systemd.tmpfiles.rules = [
    "d /share 0755 root root -"
    "d /share/Skylab 0755 root root -"
    "d /share/External 0755 root root -"
    "d /media 0755 root root -"
  ];
}
