{ config, pkgs, ... }:

let
  localNetwork = "192.168.1.0/24";
  mediasDevice = "/dev/disk/by-label/MEDIAS";
in
{
  # --- 1. Mount BTRFS Subvolumes (Local mounts for zipang) ---
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

  # --- 2. NFS Export Tree (Bind Mounts for sharing) ---
  fileSystems."/share/Skylab/Documents" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvolume=@documents" "compress=zstd" "noatime" ];
  };
  fileSystems."/share/Skylab/Games" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvolume=@games" "compress=zstd" "noatime" ];
  };
  fileSystems."/share/Skylab/Music" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvolume=@music" "compress=zstd" "noatime" ];
  };
  fileSystems."/share/Skylab/Pictures" = {
    device = mediasDevice;
    fsType = "btrfs";
    options = [ "subvolume=@pictures" "compress=zstd" "noatime" ];
  };

  # --- 3. NFS Server Service ---
  services.nfs.server = {
    enable = true;
    exports = ''
      /share           ${localNetwork}(rw,fsid=0,no_subtree_check,crossmnt)
      /share/Skylab    ${localNetwork}(rw,fsid=314116,nohide,insecure,no_subtree_check)
    '';
  };

  # Enable NFS client support (needed for mounting)
  services.rpcbind.enable = true;

  # Firewall: Port for NFS
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
