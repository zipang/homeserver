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
  # We use systemd.mounts directly for bind mounts to avoid activation issues
  # seen with fileSystems on recent NixOS versions.
  systemd.mounts = [
    {
      where = "/share/Skylab/Documents";
      what = "/home/zipang/Documents";
      type = "none";
      options = "bind,nofail";
      after = [ "home-zipang-Documents.mount" ];
      requires = [ "home-zipang-Documents.mount" ];
    }
    {
      where = "/share/Skylab/Games";
      what = "/home/zipang/Games";
      type = "none";
      options = "bind,nofail";
      after = [ "home-zipang-Games.mount" ];
      requires = [ "home-zipang-Games.mount" ];
    }
    {
      where = "/share/Skylab/Music";
      what = "/home/zipang/Music";
      type = "none";
      options = "bind,nofail";
      after = [ "home-zipang-Music.mount" ];
      requires = [ "home-zipang-Music.mount" ];
    }
    {
      where = "/share/Skylab/Pictures";
      what = "/home/zipang/Pictures";
      type = "none";
      options = "bind,nofail";
      after = [ "home-zipang-Pictures.mount" ];
      requires = [ "home-zipang-Pictures.mount" ];
    }
  ];

  # Ensure the mount point directories exist
  systemd.tmpfiles.rules = [
    "d /share 0755 root root -"
    "d /share/Skylab 0755 root root -"
    "d /share/Skylab/Documents 0755 root root -"
    "d /share/Skylab/Games 0755 root root -"
    "d /share/Skylab/Music 0755 root root -"
    "d /share/Skylab/Pictures 0755 root root -"
  ];
}
