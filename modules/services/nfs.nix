{ config, pkgs, ... }:

let
  diskLabel = "HOMELAB_DATA";
  nfsNetwork = "192.168.1.0/24";
  diskDevice = "/dev/disk/by-label/${diskLabel}";
in
{
  # --- 1. Mount BTRFS Subvolumes ---
  # These rely on the disk being labeled 'HOMELAB_DATA'
  fileSystems."/share/Music" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=Music" "compress=zstd" "noatime" ];
  };

  fileSystems."/share/Documents" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=Documents" "compress=zstd" "noatime" ];
  };

  fileSystems."/share/Pictures" = {
    device = diskDevice;
    fsType = "btrfs";
    options = [ "subvol=Pictures" "compress=zstd" "noatime" ];
  };

  # --- 2. NFS Export Tree (Bind Mounts) ---
  fileSystems."/export/Music"     = { device = "/share/Music";     options = [ "bind" ]; };
  fileSystems."/export/Documents" = { device = "/share/Documents"; options = [ "bind" ]; };
  fileSystems."/export/Pictures"  = { device = "/share/Pictures";  options = [ "bind" ]; };

  # --- 3. NFS Server Service ---
  services.nfs.server = {
    enable = true;
    exports = ''
      /export           ${nfsNetwork}(rw,fsid=0,no_subtree_check,crossmnt)
      /export/Music     ${nfsNetwork}(rw,nohide,insecure,no_subtree_check)
      /export/Documents ${nfsNetwork}(rw,nohide,insecure,no_subtree_check)
      /export/Pictures  ${nfsNetwork}(rw,nohide,insecure,no_subtree_check)
    '';
  };

  # --- 4. Firewall ---
  networking.firewall.allowedTCPPorts = [ 2049 ];
}
