# System Monitoring & Troubleshooting

This guide explains how to monitor system resources, specifically Disk I/O, on the SKYLAB server using terminal-only tools.

## Overview

We use a combination of tools to identify what is causing load on the system and which files are being accessed in real-time.

| Tool | Primary Purpose | NixOS Module |
| :--- | :--- | :--- |
| **iotop** | Identify **processes** causing Disk I/O. | `modules/system/core.nix` |
| **fatrace** | Identify **files** being read/written in real-time. | `modules/system/core.nix` |
| **lsof** | List **open files** by process or directory. | `modules/system/core.nix` |
| **btop** | General system resource overview (CPU, RAM, Net). | `modules/system/core.nix` |
| **zpool iostat**| Monitor health and I/O of **ZFS Pools**. | Native ZFS Tool |

---

## Disk I/O Troubleshooting Guide

If you notice high disk activity and want to find the culprit:

### 1. Identify the Process with `iotop`

`iotop` displays a table of current I/O usage by process.

```bash
# Show only processes actually doing I/O
sudo iotop -o

# Show accumulated I/O since iotop started
sudo iotop -a
```

### 2. Trace File Access with `fatrace`

Once you suspect a service or want to see system-wide file activity, use `fatrace`. It reports system-wide file access events (Open, Read, Write, Close).

```bash
# Watch for all WRITE events system-wide
sudo fatrace -f W

# Watch for events on a specific partition (e.g., /dev/sda1)
sudo fatrace -c /dev/sda1

# Filter by process name
sudo fatrace | grep "syncthing"
```

### 3. Check Open Files with `lsof`

If you know the Process ID (PID) from `iotop`, you can see every file it currently has open.

```bash
# List all files opened by a PID
sudo lsof -p <PID>

# List all processes accessing a specific directory
sudo lsof +D /share/Skylab/Documents
```

---

## ZFS Performance Monitoring

Since SKYLAB uses ZFS for the `BUZZ` and `WOODY` pools, use ZFS native tools for pool-level statistics.

```bash
# View I/O statistics for all pools every 5 seconds
zpool iostat -v 5

# Check if a scrub (maintenance) is currently running
zfs status
```

## General System Health

For a global view of CPU, Memory, and Network:

```bash
# Launch the interactive dashboard
btop
```

## Headless Operations & Troubleshooting

### Logs Monitoring
If a specific service is identified as the cause of I/O, check its logs:

```bash
# Monitor logs for a specific service (e.g., nextcloud)
journalctl -u php-fpm-nextcloud -f
```

### System Load
To see the system load average:
```bash
uptime
```
