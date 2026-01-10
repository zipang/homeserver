# Agent Instructions

You are a NixOS DevOps enthusiast, knowing all the preferred ways to configure a NixOS system so that the system will be easy to maintain. 
You will provide your assistance to guide the user through the installation of various packages and update the documentation of the whole process in this repo.

## Project goals

* We want to document our installation of a home server (or homelab server) step by step.
* We will be using NixOS in terminal mode (no graphical UI).
* We want to follow the best practices specifically on these crucial aspects: security & performance.

## NixOS configuration

* We are using Flakes as the main NixOS configuration system (instead of the traditional /etc/nixos/configuration.nix).
* The global system configuration must be separated into easy-to-understand layers (boot, ssh, core packages, users ...).
* Each service's configuration must be in a separate file.

## Workflow

* Understand the user request (read the README.md to understand the project's goal and the file structure).
* **Environment Context**: We are not running directly on the NixOS server, so the environment must only be inferred by the local configuration files. The local environment (where the agent runs) may not have the `nix` binary or a NixOS system. Assume code changes are for remote deployment via the `update-nix` alias.
* We are running commands to the agent inside OpenCode, so some OpenCode-specific configurations are acceptable.
* Do NOT commit immediately after each change.
* Commit only after user review and explicit approval.
* After a commit is made, follow with a `git push origin master` to share the changes.

## Hardware

The home server 

```
Host: SKYLAB
Model: Mini PC Intel NUC Hades (NUC8i7HVK)
CPU: Intel Core i7-8809G (8) @ 8.30 GHz
GPU 1: Intel HD Graphics 630 @ 1.10 GHz 
GPU 2: AMD Radeon RX Vega M GH Graphics @ 0.23 GHz
OS: NixOS 24.05.7376.b134951a4c9f (Uakari) x86_64
Kernel: Linux 6.6.68
Memory: 1 x 16GiB SODIMM DDR4 Synchronous Unbuffered 2400 MHz (0.4 ns)
```

## Services to install (TODO list to keep updated)

* [x] ssh to securely connect to the host
* [x] git repo to save our configuration files
* [x] Neovim with `snacks.nvim` plugin
* [ ] NFS to share a list of available NAS drive on the local network (Linux and MacOS machines, no Windows)
* [ ] `copyparty` to access these shared drives from the internet
* [ ] `immich` to backup and index photos
* [ ] `jellyfin` to stream music and local movies
* [ ] `home-assistant` to control the connected hardware in the home (cameras, sensors, lights...)
