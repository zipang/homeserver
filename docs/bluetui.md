# Bluetui Quick Start Guide

[Bluetui](https://github.com/pythops/bluetui) is a TUI for managing Bluetooth devices on Linux.

Bluetui is installed via `modules/system/core.nix`.

## Prerequisites

Bluetooth support must be enabled in the kernel and the `bluetooth` service must be running. These are configured in `modules/system/core.nix`:

```nix
hardware.bluetooth.enable = true;
services.bluetooth.enable = true;
```

## Usage

```bash
bluetui
```

## Keybindings

| Key | Action |
|-----|--------|
| `Up/Down` | Navigate devices |
| `Enter` | Connect/Disconnect |
| `d` | Disconnect |
| `p` | Pair |
| `u` | Unpair |
| `r` | Scan for devices |
| `q` / `Esc` | Quit |

## Troubleshooting

Check Bluetooth service status:
```bash
systemctl status bluetooth
```

View Bluetooth logs:
```bash
journalctl -u bluetooth.service -f
```

Ensure the Bluetooth adapter is powered on in bluetui (`o` toggle).
