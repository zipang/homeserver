{ config, pkgs, ... }:

let
  diskLabel = "MEDIAS";
  nfsNetwork = "192.168.1.0/24";
  diskDevice = "/dev/disk/by-label/${diskLabel}";
in
{
  # --- 1. Mount BTRFS Subvolumes (Local mounts for zipang) ---
  fileSystems."/home/zipang/Pictures" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=@pictures" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Documents" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=@documents" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Music" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=@music" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Games" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=@games" "compress=zstd" "noatime" ];
  };

  fileSystems."/home/zipang/Workspace" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=@workspace" "compress=zstd" "noatime" ];
  };

  # --- 2. NFS Export Tree (Bind Mounts for sharing) ---
  fileSystems."/share/Skylab/Documents" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvolume=@documents" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Games" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvolume=@games" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Music" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvolume=@music" "compress=zstd" "noatime" "bind" ];
  };
  fileSystems."/share/Skylab/Pictures" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvolume=@pictures" "compress=zstd" "noatime" "bind" ];
  };

  # --- 3. NFS Server Service ---
  services.nfs.server = {
    enable = true;
    exports = ''
      /share           ${nfsNetwork}(rw,fsid=0,no_subtree_check,crossmnt)
      /share/Skylab    ${nfsNetwork}(rw,nohide,insecure,no_subtree_check)
    '';
  };

  # Enable NFS client support (needed for mounting)
  services.rpcbind.enable = true;

  # Firewall: Port for NFS
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
