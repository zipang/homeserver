# NixOS Homelab Installation Guide

This guide describes how to bootstrap your NixOS home server and transition to a GitOps workflow using Nix Flakes and AI Agents (OpenCode).

## Phase 1: Bootstrapping NixOS (The Minimal ISO Phase)

The goal of this phase is to get a functional, minimal NixOS system running from which we can then clone the repository and apply the final configuration.

### 1. Boot from ISO
Prepare a bootable USB using the [NixOS Minimal ISO](https://nixos.org/download.html). Boot your server from it.

### 2. Prepare the Disk
Identify your drive using `lsblk` (e.g., `/dev/nvme0n1` or `/dev/sda`).

```bash
# Define the disk variable (replace with your actual disk)
export DISK=/dev/sda

# Create GPT partition table
sudo parted $DISK -- mklabel gpt

# Create EFI partition (512MB)
sudo parted $DISK -- mkpart ESP fat32 1MiB 512MiB
sudo parted $DISK -- set 1 esp on

# Create Root partition (remaining space)
sudo parted $DISK -- mkpart primary 512MiB 100%
```

### 3. Format Partitions

```bash
# Format EFI partition
sudo mkfs.fat -F 32 -n boot ${DISK}1

# Format Root partition (using ext4 for simplicity, or btrfs)
sudo mkfs.ext4 -L nixos ${DISK}2
```

### 4. Mount and Generate Config

```bash
# Mount root
sudo mount /dev/disk/by-label/nixos /mnt

# Mount boot
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot

# Generate initial configuration
sudo nixos-generate-config --root /mnt
```

### 5. Initial Installation
Before installing, ensure the generated config is enough to boot (usually it is).

```bash
sudo nixos-install
# Set your root password when prompted
sudo reboot
```

---

## Phase 2: Transition to GitOps (Post-Reboot)

Now that you have rebooted into your fresh NixOS, log in as root.

### 1. Initial User Setup
Before cloning the repository, you need a user with a home directory.

1. **Create the user** (replace `username` with your desired login):
   ```bash
   useradd -m -G wheel username
   passwd username
   ```
2. **Switch to the user**:
   ```bash
   su - username
   ```

### 2. Enable Flakes & Install Git
If you haven't enabled flakes in the initial install, you can do it temporarily for the current session:
```bash
nix-shell -p git nixFlakes
```

### 3. GitHub Integration
To sync this repository with GitHub, generate an SSH key on the server and add it to your GitHub account:

1. **Generate an SSH key**:
   ```bash
   ssh-keygen -t ed25519 -C "your.email@example.com"
   ```
2. **Add the key to GitHub**:
   - Copy the public key: `cat ~/.ssh/id_ed25519.pub`
   - Add it to [GitHub Settings > SSH Keys](https://github.com/settings/keys).

### 4. Clone the Repository
```bash
git clone git@github.com:youruser/homeserver.git ~/homeserver
cd ~/homeserver
```

### 5. Hardware Alignment
Replace the generic hardware configuration with the one specific to this machine:
```bash
cp /etc/nixos/hardware-configuration.nix ~/homeserver/hosts/HOSTNAME/hardware-configuration.nix
```

### 6. The "Secrets Hack" (Crucial)
To keep the server's sensitive details (domains, admin email, etc.) out of the public Git history while still allowing Nix Flakes to see them, we use the "intent-to-add" hack.

1. **Create the secrets file**:
   ```bash
   cp hosts/HOSTNAME/secrets.nix.example hosts/HOSTNAME/secrets.nix
   # Edit it with your real values
   nano hosts/HOSTNAME/secrets.nix
   ```

2. **Mark as "intent-to-add"**:
   Nix Flakes only see files that are tracked by Git. Since `secrets.nix` is in `.gitignore`, we must force Git to acknowledge it without actually committing its content.
   ```bash
   git add -N -f hosts/HOSTNAME/secrets.nix
   ```
   *Note: This makes the file visible to the Nix build process, but it will NOT be included in your next `git commit` unless you explicitly force it.*

### 7. Apply Final Configuration
Finally, run the update script to apply the full configuration for your host. 

> **Note**: Ensure that your `flake.nix` has a `nixosConfigurations` entry matching your `HOSTNAME`, and that the `scripts/update-nix` script points to the correct flake attribute.

```bash
sudo ./scripts/update-nix
```

---

## Phase 3: Service Management & Secrets

Once the base system is running, you can start enabling specific services and generating their required secrets.

### 1. Enabling Services
All available services are located in `modules/services/`. To enable a service for your host:

1. Open `hosts/HOSTNAME/configuration.nix`.
2. Locate the `imports` list.
3. Uncomment the services you wish to activate:
   ```nix
   imports = [
     ./hardware-configuration.nix
     # ...
     ../../modules/services/nginx.nix
     ../../modules/services/fail2ban.nix
     ../../modules/services/syncthing.nix
     # ../../modules/services/authelia.nix  # Uncomment to enable
   ];
   ```
4. Follow the instructions to configure the specific service found inside docs/servicename.md 
5. Run `sudo ./scripts/update-nix` to apply changes.

### 2. Generating Runtime Secrets
Many services (Nextcloud, Authelia, zrok) require unique secrets, database passwords, or tokens that should not be stored in Git. We provide helper scripts in the `scripts/` directory to generate these safely on the host.

*   **Nextcloud**: `./scripts/generate-nextcloud-secrets.sh`
*   **Authelia**: `./scripts/generate-authelia-secrets.sh`
*   **zrok**: `./scripts/generate-zrok-setup.sh`

These scripts typically generate files inside the `/var/lib/secrets/` directory.

For instance to enable **SSH Access** from selected hosts : check the import of the line `../../system/ssh.nix` and follow the instructions to place your authorized public keys in `/var/lib/secrets/ssh/authorized_keys`.
