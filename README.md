# SKYLAB Homelab - NixOS GitOps

This repository contains the NixOS configuration for the SKYLAB home server (Intel NUC Hades Canyon).

## Repository Structure

```text
.
├── flake.nix               # Entry point for the Nix Flake
├── hosts/                  # Host-specific configurations
│   └── SKYLAB/
│       ├── default.nix     # Main configuration for SKYLAB
│       └── hardware.nix    # Hardware-specific config (scanned from machine)
├── modules/                # Reusable NixOS modules
│   ├── services/           # Services (NFS, Docker, etc.)
│   └── system/             # System settings (SSH, Core, Nix)
└── docs/                   # Detailed documentation
```

## How to Deploy

### 1. Preparation (on the Server)

Ensure you have your `hardware-configuration.nix` ready.

```bash
# Copy your existing hardware config into the repo
cp /etc/nixos/hardware-configuration.nix ./hosts/SKYLAB/hardware.nix
```

### 2. Apply Configuration

To apply the configuration using Flakes:

```bash
sudo nixos-rebuild switch --flake .#SKYLAB
```

### 3. Update the System

```bash
# Update the flake inputs (nixpkgs version)
nix flake update

# Apply changes
sudo nixos-rebuild switch --flake .#SKYLAB
```

## Security & Best Practices
- **SSH**: Root login is disabled. Password authentication is disabled.
- **NFS**: Configured for BTRFS subvolumes with bind mounts for NFSv4 compliance.
- **Flakes**: Enabled by default for reproducible builds.
- **GC**: Automatic weekly garbage collection to keep the system clean.
