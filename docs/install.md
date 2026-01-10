# NixOS Homelab Installation Guide

## Recommended NixOS ISO

**Best Choice: NixOS Minimal Graphical ISO**
- **Download**: https://nixos.org/download.html
- **Version**: Latest stable (24.05 at time of writing)
- **Architecture**: x86_64 (standard for most servers)
- **Type**: Minimal Graphical (includes basic tools, easier setup)

## NixOS Configuration File Overview

This configuration includes:
- Docker support
- NFS client
- Security settings  
- User accounts
- Your core services

```nix
# /etc/nixos/configuration.nix

{ config, lib, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
    ];

  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.enableNvidia = false;  # Set to true if using NVIDIA GPU
  
  # Enable NFS client support
  services.rpcbind.enable = true;
  services.nfs.client.enable = true;

  # Network configuration
  networking.hostName = "homelab";
  networking.networkmanager.enable = true;

  # Time zone and internationalization
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # User accounts
  users.users = {
    homelab = {
      isNormalUser = true;
      description = "Homelab administrator";
      extraGroups = [ "wheel" "docker" "networkmanager" ];
      openssh.authorizedKeys.keys = [
        # Add your SSH public key here
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."
      ];
      initialHashedPassword = "$6$rounds=656000$...";
    };
  };

  # Enable SSH
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.settings.PasswordAuthentication = false;

  # Firewall
  networking.firewall.enable = true;

  # Essential packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    nfs-utils
    docker-compose
    htop
    btop
  ];

  # System version
  system.stateVersion = "24.05";
}
```

## Step-by-Step Installation

### Phase 1: Installation

1. **Download and create bootable USB:**
   ```bash
   # Download NixOS ISO
   wget https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso
   
   # Create bootable USB (replace /dev/sdX with your USB device)
   sudo dd if=nixos-minimal-x86_64-linux.iso of=/dev/sdX bs=4M status=progress oflag=none
   ```

2. **Boot from USB and partition disks:**
   ```bash
   # Start installer
   sudo su
   
   # Partition disk (adjust for your setup)
   gdisk /dev/sda
   # Create EFI partition (512M), Linux partition (rest)
   
   # Format partitions
   mkfs.fat -F32 /dev/sda1
   mkfs.ext4 /dev/sda2
   
   # Mount for installation
   mount /dev/sda2 /mnt
   mkdir -p /mnt/boot
   mount /dev/sda1 /mnt/boot
   ```

3. **Generate and apply configuration:**
   ```bash
   # Generate initial configuration
   nixos-generate-config --root /mnt
   
   # Edit the configuration
   vim /mnt/etc/nixos/configuration.nix
   # Add the complete configuration from above
   ```

4. **Install NixOS:**
   ```bash
   nixos-install --root /mnt
   
   # Reboot into new system
   reboot
   ```

### Phase 2: Post-Installation Setup

1. **Complete basic setup:**
   ```bash
   # Set user password
   sudo passwd homelab
   
   # Add SSH key (replace with your actual key)
   mkdir -p /home/homelab/.ssh
   echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..." >> /home/homelab/.ssh/authorized_keys
   chown -R homelab:homelab /home/homelab/.ssh
   chmod 700 /home/homelab/.ssh
   chmod 600 /home/homelab/.ssh/authorized_keys
   ```

2. **Update system:**
   ```bash
   sudo nix-channel --update
   sudo nixos-rebuild switch --upgrade
   ```

### Phase 3: NFS Server Configuration

We share our local BTRFS subvolumes using NFSv4 with a modular configuration.

1. **Create the NFS configuration file:**
   Save the following as `/etc/nixos/nfs-configuration.nix` (or use the template provided in this repo).

2. **Update your main configuration:**
   Edit `/etc/nixos/configuration.nix` and add the new file to the `imports` list:
   ```nix
   imports =
     [ 
       ./hardware-configuration.nix
       ./nfs-configuration.nix
     ];
   ```

3. **Label your drives (if not already done):**
   ```bash
   # Replace /dev/sdX with your actual partition
   sudo btrfs filesystem label /dev/sdX HOMELAB_DATA
   ```

4. **Apply and Verify:**
   ```bash
   sudo nixos-rebuild switch
   
   # Check if exports are active
   showmount -e localhost
   ```

### Phase 4: Client Connections

### Immich with NFS Storage

Create `/home/homelab/docker/immich/compose.yml`:

```yaml
version: '3.8'

services:
  immich-server:
    image: altran1502/immich-server:latest
    container_name: immich-server
    restart: unless-stopped
    ports:
      - "2283:3001"
    environment:
      - REDIS_HOSTNAME=immich-redis
      - DB_HOSTNAME=immich-postgres
      - DB_USERNAME=postgres
      - DB_PASSWORD=change_this_password
      - DB_DATABASE_NAME=immich
    volumes:
      - /mnt/nas/pictures/immich:/usr/src/app/upload
      - /mnt/nas/pictures/photos:/media/photos
    depends_on:
      - immich-redis
      - immich-postgres

  immich-redis:
    image: redis:6-alpine
    container_name: immich-redis
    restart: unless-stopped

  immich-postgres:
    image: postgres:14-alpine
    container_name: immich-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=change_this_password
      - POSTGRES_DB=immich
    volumes:
      - ./postgres-data:/var/lib/postgresql/data

networks:
  default:
    driver: bridge
```

### CopyParty with NFS Folders

Create `/home/homelab/docker/copyparty/compose.yml`:

```yaml
version: '3.8'

services:
  copyparty:
    image: copyparty/cp-cmd:latest
    container_name: copyparty
    restart: unless-stopped
    ports:
      - "3923:3923"
    volumes:
      - /mnt/nas/documents:/src/documents:rw
      - /mnt/nas/pictures:/src/pictures:ro
      - /mnt/nas/music:/src/music:ro
    command: >
      --port=3923 
      --rw=/src/documents 
      --ro=/src/pictures 
      --ro=/src/music
      --verbose
    networks:
      - default
```

### Portainer for Management

Create `/home/homelab/docker/portainer/compose.yml`:

```yaml
version: '3.8'

services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "8000:8000"
      - "9443:9443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer-data:/data
    command: >
      --admin-password='set_strong_password_here'
      --host=unix:///var/run/docker.sock
```

## Deployment Commands

```bash
# Create directory structure
mkdir -p ~/docker/{immich,copyparty,portainer}

# Deploy services
cd ~/docker/immich && docker-compose up -d
cd ~/docker/copyparty && docker-compose up -d
cd ~/docker/portainer && docker-compose up -d

# Check status
docker-compose ps
```

## Access URLs

- **Immich**: http://your-server-ip:2283
- **CopyParty**: http://your-server-ip:3923  
- **Portainer**: http://your-server-ip:8000 or https://your-server-ip:9443

## Configuration Management

All your homelab configuration is now in:
- **System**: `/etc/nixos/configuration.nix`
- **Services**: `~/docker/*/compose.yml`
- **NFS**: Managed via NixOS config
- **Version control**: Git repository of config files

## Backup and Restore

```bash
# Backup configurations
git add .
git commit -m "Update homelab configuration"
git push origin main

# Restore on new system
git clone your-repo.git
sudo cp configuration.nix /etc/nixos/
sudo nixos-rebuild switch

# Redeploy services
cd ~/docker && find . -name "compose.yml" -exec docker-compose -f {} up -d \;
```

## Security Notes

1. **Change all default passwords** before deployment
2. **Use HTTPS** with reverse proxy for production
3. **Regular updates**: `sudo nixos-rebuild switch --upgrade`
4. **Firewall**: NixOS firewall is enabled by default
5. **SSH keys**: Disable password authentication after key setup

## Troubleshooting

- **NFS mounts failing**: Check NAS IP, permissions, and network connectivity
- **Docker permission errors**: Ensure user is in docker group  
- **Service not starting**: Check Docker logs with `docker logs container-name`
- **Network issues**: Verify firewall settings and port availability

This setup provides a fully reproducible, version-controlled homelab with centralized storage via NFS.