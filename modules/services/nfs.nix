{ config, pkgs, ... }:

{
  # --- 1. NFS Server Configuration ---
  services.nfs.server = {
    enable = true;
    # NFSv4 pseudo-root configuration
    # we export /share as the root (fsid=0)
    # crossmnt allows clients to automatically discover sub-mounts like /share/Skylab
    exports = ''
      /share         192.168.1.0/24(rw,fsid=0,no_subtree_check,crossmnt)
      /share/Skylab  192.168.1.0/24(rw,nohide,insecure,no_subtree_check,crossmnt)
      /share/Storage 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,crossmnt)
    '';
  };

  # --- 2. Firewall Configuration ---
  # Open port 2049 for NFS v4
  networking.firewall.allowedTCPPorts = [ 2049 ];
  
  # RPCBind is required for NFS
  services.rpcbind.enable = true;
}
