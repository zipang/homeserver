{ config, pkgs, lib, ... }:

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

  # --- 1b. Shared AI model library (MEDIAS) ---
  # Btrfs subvolume @llms, created once on the server:
  #   sudo btrfs subvolume create /mnt/medias/@llms
  # It is mounted directly under the NFS export root, so `crossmnt` in
  # modules/services/nfs.nix publishes it as /share/Skylab/LLMS with no
  # extra export entry.
  fileSystems."/share/Skylab/LLMS" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvol=@llms" "compress=zstd" "noatime" ];
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
  # We use 'legacy' mountpoints in ZFS and define them here for systemd control.
  # 'nofail' prevents boot hangs if the USB enclosure is disconnected.

  fileSystems."/share/Storage/BUZZ" = {
    device = "BUZZ";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" "X-systemd.idle-timeout=60" "x-systemd.mount-timeout=5s" ];
  };

  fileSystems."/var/lib/immich" = {
    device = "BUZZ/immich";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" "x-systemd.mount-timeout=5s" ];
  };

  fileSystems."/share/Storage/WOODY" = {
    device = "WOODY";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" "X-systemd.idle-timeout=60" "x-systemd.mount-timeout=5s" ];
  };

  fileSystems."/share/Storage/WOODY/photos" = {
    device = "WOODY/photos";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" "x-systemd.mount-timeout=5s" ];
  };

  fileSystems."/var/lib/nextcloud" = {
    device = "WOODY/nextcloud";
    fsType = "zfs";
    options = [ "nofail" "X-systemd.automount" "x-systemd.mount-timeout=5s" ];
  };

  # Ensure parent directories exist (BUZZ and WOODY are managed by copyparty/automount)
  systemd.tmpfiles.rules = [
    "d /share 0755 root root -"
    "d /share/Skylab 0755 root root -"
    # Group-writable by `users` so zipang downloads models and the llama-cpp
    # service (member of `users`) can read them.
    "d /share/Skylab/LLMS 2775 zipang users -"
    "d /share/Storage 0775 zipang users -"
    "d /share/Storage/WOODY/photos 0775 zipang users -"
    "d /media 0755 root root -"
  ] ++ lib.optionals config.services.nextcloud.enable [
    "d /var/lib/nextcloud 0750 nextcloud nextcloud -"
  ];
}
