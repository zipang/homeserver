# NFS Shared Drives

## Goal

We want to share the server's storage using NFS (Network File System) to provide high-performance file access for Linux-to-Linux connections. This complements our SAMBA setup and allows for comparative performance testing.

## Configuration Reference

The complete list of available options for the `services.nfs` module can be found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.nfs.server).

## Full Configuration Template

You can use this template in `modules/services/nfs.nix` to configure the NFS server:

```nix
{ config, pkgs, ... }: {
  services.nfs.server = {
    enable = true;
    # NFSv4 pseudo-root configuration
    # we export /share as the root (fsid=0)
    exports = ''
      /share         192.168.1.0/24(rw,fsid=0,no_subtree_check,crossmnt)
      /share/Skylab  192.168.1.0/24(rw,nohide,insecure,no_subtree_check,crossmnt,no_root_squash,fsid=1)
      /share/Storage 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,crossmnt,no_root_squash,fsid=2)
    '';
  };

  # Firewall configuration for NFS v4
  networking.firewall.allowedTCPPorts = [ 2049 ];
  services.rpcbind.enable = true;
}
```

## Configuration

### Storage Structure
The NFS export uses the same stable structure as SAMBA:
- **Root Export**: `/share` (configured as NFSv4 pseudo-root with `fsid=0`)
- **Data Tree**: `/share/Skylab/[Documents, Games, Music, Pictures]` (bind-mounted from user home directories)

### NFS Service (`modules/services/nfs.nix`)
The NFS server is configured for the local network (192.168.1.0/24):
- **NFSv4**: Standard port 2049 is opened in the firewall.
- **Pseudo-root**: `/share` is the entry point. Clients mounting `SKYLAB:/` will see the `Skylab` directory.
- **Options**:
    - `rw`: Read-Write access.
    - `crossmnt`: Allows clients to move from the pseudo-root into sub-mounts automatically. This is essential for ZFS datasets nested under a single export.
    - `nohide`: Ensures that the bind-mounted directories under `/share/Skylab` are visible to clients.
    - `no_root_squash`: Allows remote root users (via `sudo`) to have root permissions on the filesystem. Useful for homelab management.
    - `fsid=X`: Unique filesystem IDs required for NFSv4 to distinguish between multiple exports under the pseudo-root.

## How to Access

### Linux CLI
To mount the entire Skylab share:
```bash
sudo mkdir -p /mnt/skylab
sudo mount -t nfs4 skylab.local:/Skylab /mnt/skylab
```

To mount the root export (showing all shares under `/share`):
```bash
sudo mount -t nfs4 skylab.local:/ /mnt/path
```

### Automatic Mount (/etc/fstab)
For the best experience, use `nfs4` and ensure your local UID matches the server's (typically `1000` for the first user).

Add the following to your client's `/etc/fstab`:
```fstab
skylab.local:/Skylab  /media/SKYLAB  nfs4  rw,user,noauto,x-systemd.automount,x-systemd.idle-timeout=600 0 0
skylab.local:/Storage/WOODY /media/WOODY nfs4 rw,user,noauto,x-systemd.automount 0 0
```

## Performance Testing (NFS vs Samba)

To compare the performance between the two protocols, you can use `fio` or simple `rsync` / `dd` tests.

### Simple Write Test
```bash
# Samba
dd if=/dev/zero of=/mnt/samba/testfile bs=1M count=1024 conv=fdatasync

# NFS
dd if=/dev/zero of=/mnt/nfs/testfile bs=1M count=1024 conv=fdatasync
```

### Simple Read Test
```bash
# Clear cache before each test if possible (requires sudo on client)
# sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'

# Samba
time cp /mnt/samba/testfile /dev/null

# NFS
time cp /mnt/nfs/testfile /dev/null
```

## Headless Operations & Troubleshooting

Use these commands to monitor the NFS service:

### View Service Logs
```bash
journalctl -u nfs-server.service -f
```

### Service Status
```bash
systemctl status nfs-server.service
```

### Active Exports
To verify what is currently being exported by the server:
```bash
sudo exportfs -v
```

### RPC Status
Check if the required RPC services are running:
```bash
rpcinfo -p localhost
```
