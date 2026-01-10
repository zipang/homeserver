# NixOS Homelab Installation Guide

This guide describes how to bootstrap the SKYLAB home server and switch to the GitOps workflow using Nix Flakes.

## Phase 1: Initial Installation

1. **Prepare Bootable USB**: Use the [Nixos Minimal ISO](https://nixos.org/download.html).
2. **Partition & Format**:
   - EFI Partition (FAT32): `/boot`
   - Root Partition (Ext4 or BTRFS): `/`
3. **Generate Initial Config**:
   ```bash
   sudo nixos-generate-config --root /mnt
   ```
4. **Install**:
   ```bash
   sudo nixos-install --root /mnt
   reboot
   ```

## Phase 2: Transition to GitOps

Once the system is booted and Git is installed, you can transition to this repository's configuration.

### 1. Enable Flakes (if not already done)
Ensure your current `/etc/nixos/configuration.nix` contains:
```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```
Then run `sudo nixos-rebuild switch`.

### 2. Prepare Secrets & Labels
- Ensure `/etc/nixos/ssh/authorized_keys` exists with your public keys.
- Ensure your disks are labeled correctly:
  - `MEDIAS` for the storage drive.
  - `SWAP` for the swap partition.

### 3. Clone this Repository

```bash
git clone https://github.com/youruser/homeserver.git ~/homeserver
cd ~/homeserver
```

### 3. Import Hardware Configuration
Copy the auto-generated hardware config from your machine into the repo:
```bash
cp /etc/nixos/hardware-configuration.nix ~/homeserver/hosts/SKYLAB/hardware.nix
```

### 4. Apply the Flake Configuration
```bash
sudo nixos-rebuild switch --flake .#SKYLAB
```

## Phase 3: Post-Installation

### GitHub Integration
To sync this repository with GitHub from SKYLAB:

1. **Generate an SSH key**:
   ```bash
   ssh-keygen -t ed25519 -C "christophe.desguez@gmail.com"
   ```
   Press Enter to accept the defaults.
2. **Add the key to GitHub**:
   - Copy the public key: `cat ~/.ssh/id_ed25519.pub`
   - Go to GitHub -> Settings -> SSH and GPG keys -> New SSH key.
   - Paste the content and save.
3. **Test the connection**:
   ```bash
   ssh -T git@github.com
   ```

### Setting up the Admin User
The `homelab` user is defined in `modules/system/core.nix`. You must set its password manually after the first deployment:
```bash
sudo passwd homelab
```

### NFS Setup
Ensure your data drive is labeled `HOMELAB_DATA` for the NFS module to find it:
```bash
sudo btrfs filesystem label /dev/sdX HOMELAB_DATA
```
Check exports:
```bash
showmount -e localhost
```
