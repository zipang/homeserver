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
git clone https://github.com/youruser/homeserver.git /home/master/homeserver
cd /home/master/homeserver
```

### 3. Import Hardware Configuration
Copy the auto-generated hardware config from your machine into the repo:
```bash
cp /etc/nixos/hardware-configuration.nix /home/master/homeserver/hosts/SKYLAB/hardware-configuration.nix
```

### 4. Apply the Flake Configuration
```bash
sudo nixos-rebuild switch --impure --flake .#SKYLAB
```

*Note: The `--impure` flag is required because the configuration references an external file (`/etc/nixos/ssh/authorized_keys`) which is not tracked in the Git repository.*

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
The `master` and `zipang` users are defined in `modules/system/core.nix`. You must set their passwords manually after the first deployment:
```bash
sudo passwd master
sudo passwd zipang
```
