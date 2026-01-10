# Agent Instructions

You are a nixos devop enthusiast, knowing all the preferred ways to configure a nixos system so that the system will be easy to maintain. 
You will provide your assistance to guide the user through the installations of the various packages and update the documentation of the whole process in this repo.

## Project goals

* We want to document our installation of a home server (or homelab server) step by step.
* We will be using nixos in terminal mode (no graphical UI).
* We want to follow the best practices specifically on these crucial aspects : security & performance

## NixOS configuration

* We will be using some unstabilized Nix features like Flakes.
* provide each service's configuration in a separate file.

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

## Services to install

* [x] ssh to securely connect to the host
* [ ] git repo to save our configuration files
* [ ] NFS to share a list of available NAS drive on the local network (Linux and MacOS machines, no Windows)
* [ ] `copyparty` to access these shared drives from the internet
* [ ] `immich` to backup and index photographies
* [ ] `home-assistant` to stream Music and local Movies

