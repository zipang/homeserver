# System Monitoring & Troubleshooting

This guide explains how to monitor system resources, specifically Disk I/O, on the SKYLAB server using both real-time web dashboards and terminal-only tools.

## Overview

We use a combination of **Netdata** for a persistent web-based overview and specialized CLI tools for deep-dive troubleshooting.

| Tool | Primary Purpose | NixOS Module | Access / Command |
| :--- | :--- | :--- | :--- |
| **Netdata** | **Real-time Web Dashboard** for all metrics. | `modules/services/netdata.nix` | [http://monitor.{{privateDomain}}](http://monitor.{{privateDomain}}) |
| **iotop** | Identify **processes** causing Disk I/O. | `modules/system/core.nix` | `sudo iotop -o` |
| **fatrace** | Identify **files** being read/written in real-time. | `modules/system/core.nix` | `sudo fatrace -f W` |
| **lsof** | List **open files** by process or directory. | `modules/system/core.nix` | `sudo lsof -p <PID>` |
| **btop** | General system resource overview (CPU, RAM, Net). | `modules/system/core.nix` | `btop` |
| **zpool iostat**| Monitor health and I/O of **ZFS Pools**. | Native ZFS Tool | `zpool iostat -v 5` |

---

## Netdata Web Dashboard

Netdata provides an incredibly detailed dashboard with zero-configuration. It is particularly useful for:
*   **ZFS ARC Health**: Monitor hit rates and cache size (crucial for ZFS performance).
*   **Disk Latency**: Identify if your external USB-C drives are causing bottlenecks.
*   **Long-term History**: See what happened while you were away.

### Security
The dashboard is accessible via `monitor.${privateDomain}` and is restricted to your **Local Network** only. It is further protected by Nginx-level security.

---

## Disk I/O Troubleshooting Guide

If you notice high disk activity (like the `dsl_scan_iss` kernel thread) and want to find the culprit:

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
zpool status
```

*Note: `dsl_scan_iss` is the kernel process responsible for ZFS scrubbing. This is normal maintenance.*

---

## Headless Operations & Troubleshooting

### Logs Monitoring
If a specific service is identified as the cause of I/O, check its logs:

```bash
# Monitor logs for a specific service (e.g., netdata)
journalctl -u netdata.service -f
```

### System Load
To see the system load average:
```bash
uptime
```
