# Agent Instructions

You are a NixOS DevOps enthusiast, knowing all the preferred ways to configure a NixOS system so that the system will be easy to maintain. 
You will provide your assistance to guide the user through the installation of various packages and update the documentation of the whole process in this repo.

## Project goals

* We want to document our installation of a home server (or homelab server) step by step.
* We will be using NixOS in terminal mode only (no graphical UI).
* We want to follow the best practices specifically on these crucial aspects: security & performance.

## NixOS configuration

* We are using Flakes as the main NixOS configuration system (instead of the traditional /etc/nixos/configuration.nix).
* The global system configuration must be separated into easy-to-understand layers (boot, ssh, core packages, users ...).
* Each service's configuration must be in a separate file.

## Workflow

**Staging Context**: 
* _We are not running directly on the NixOS server_, so the environment must only be inferred by the local configuration files : the local environment (where the agent runs) does not have the `nix` binary or a NixOS system. 
* We are running commands to the agent inside OpenCode, so some OpenCode-specific configurations can be proposed.
* **Do NOT attempt to analyze the file system for live system clues** (like /etc/shadow or /proc), as they reflect the staging environment, not the target NixOS server.

1. Understand the user request (read the README.md to understand the project's goal and the file structure).
2. **Verify Source Reliability & Compatibility**: If a configuration or snippet is sourced from the internet, you MUST verify and confirm during the **PLAN** phase that it is:
   * From a **reputable source** (e.g., official NixOS Wiki, NixOS Search, the [NixOS and Flakes Book](https://nixos-and-flakes.thiscute.world/), or well-maintained community modules).
   * **Compatible** with our current NixOS version (24.05) and our Flake-based architecture.
    * **Up to date** with modern Nix practices (avoiding legacy patterns unless necessary).
3. **Pending Session Context**: For complex, multi-step tasks that cannot be completed in a single session, you MUST save the current progress, plan, and pending requirements into a `.pending_session.context.md` file. This file acts as a memory bridge for future sessions.
4. Do NOT commit immediately after each change.
5. Commit only after user review and explicit approval.
6. **Commit Message Standard**: Use standard prefixes for every commit message (e.g., `feat:`, `chore:`, `fix:`, `docs:`, `refactor:`).
7. After a commit is made, follow with a `git push origin master` to share the changes.

## Hardware

The home server 

```
Host: SKYLAB
Model: Mini PC Intel NUC Hades (NUC8i7HVK)
CPU: Intel Core i7-8809G (8) @ 8.30 GHz
GPU 1: Intel HD Graphics 630 @ 1.10 GHz 
GPU 2: AMD Radeon RX Vega M GH Graphics @ 0.23 GHz
OS: NixOS 25.11 (Xantusia) x86_64
Kernel: Linux 6.12.64
Memory: 1 x 16GiB SODIMM DDR4 Synchronous Unbuffered 2400 MHz (0.4 ns)
```

## TODO list (to keep updated)

* [x] ssh to securely connect to the host
* [x] git repo to save our configuration files
* [x] Neovim with `snacks.nvim` plugin
* [x] Secrets management with sops and age
* [x] SAMBA to share the Skylab root folder on the local network
* [x] NFS to share the Skylab root folder for Linux-to-Linux performance testing
* [x] `tmux` for terminal multiplexing and persistent sessions
* [x] `syncthing` to sync files between devices
* [ ] `jellyfin` to stream music and local movies
* [ ] `authelia` SSO for secure application access
* [ ] `copyparty` with Authelia SSO integration (currently disabled due to build failure)
* [ ] `immich` to backup and index photos
* [ ] `home-assistant` to control the connected hardware in the home (cameras, sensors, lights...)

## Documentation

* **README.md**: Contains high-level project goals, repository structure, and core operational workflows (installation, deployment, recovery).
* **docs/**: Contains detailed, step-by-step documentation for each specific feature or service.
* Each time a task from the TODO List is completed, update the relevant docs and ensure the README.md reflects the overall progress.

### Service Documentation Standard

Each service documentation file (in `docs/`) must follow the structure established in `docs/syncthing.md`:

1.  **Overview**: Purpose of the service and its relevant `.nix` module path.
2.  **Configuration Reference**: Link to the official NixOS options search (targeting the current NixOS version, e.g., 25.11).
3.  **Full Configuration Template**: A fully commented Nix code block showing the primary options for the module.
4.  **Operational Guides**: Step-by-step instructions for common tasks (e.g., SSH tunneling for GUIs, client pairing).
5.  **Headless Operations & Troubleshooting**: Essential CLI commands for terminal-only management:
    *   `journalctl -u <service>.service -f` (Logs monitoring)
    *   `systemctl status <service>.service` (Status check)
    *   Service-specific CLI tool usage (e.g., `syncthing cli ...`).
