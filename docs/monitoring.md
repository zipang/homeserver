# System Monitoring & Troubleshooting

This guide explains how to monitor system resources, specifically Disk I/O, on the SKYLAB server using both real-time web dashboards and terminal-only tools.

## Overview

We use a combination of **Netdata** for a persistent web-based overview and specialized CLI tools for deep-dive troubleshooting.

| Tool | Primary Purpose | NixOS Module | Access / Command |
| :--- | :--- | :--- | :--- |
| **Netdata** | **Real-time Web Dashboard** for all metrics. | `modules/services/netdata.nix` | [https://monitor.{{privateDomain}}](https://monitor.{{privateDomain}}) |
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

---

## SSH & Git Troubleshooting

### `hostkeys_foreach failed for /home/zipang/.ssh/known_hosts: Permission denied`

Symptom, when running any `git`/`ssh` command as `zipang` (for instance
`git clone git@github.com:...`):

```text
hostkeys_find_by_key_hostfile: hostkeys_foreach failed for
/home/zipang/.ssh/known_hosts: Permission denied
The authenticity of host 'github.com (140.82.121.3)' can't be established.
```

**Cause.** `/home/zipang/.ssh` is owned by `root:root` with mode `0700`, so the
SSH client running as `zipang` cannot even stat `known_hosts` (or read a private
key). NixOS never creates this directory: it provisions `$HOME` (owner = the
user, mode `0700`) and reads authorized keys from `/etc/ssh/authorized_keys.d`,
so `~/.ssh` is created by the first tool that needs it. If that tool ran under
`sudo` — `sudo ssh ...`, `sudo git clone git@...`, or a `sudo -i` shell — the
directory is born root-owned and stays that way. This is the usual root cause —
nothing in this flake creates `~/.ssh` (`users.users.*` only manage `$HOME`,
`programs.git` only writes the system-wide config).

**Fix.** The configuration re-asserts the correct ownership on every boot via
`systemd.tmpfiles.rules` in `modules/system/users.nix`, so a rebuild repairs it:

```bash
update-nix
```

Without waiting for a rebuild, the equivalent manual repair is:

```bash
sudo chown -R zipang:users /home/zipang/.ssh
sudo chmod 700 /home/zipang/.ssh
```

**Verify:**

```bash
ls -ld ~/.ssh            # drwx------ zipang users
ssh -T git@github.com    # "Hi zipang! You've successfully authenticated..."
```

### `WARNING: UNPROTECTED PRIVATE KEY FILE!`

Only the *ownership* of the directory contents is repaired automatically; modes
are left untouched. If the SSH client refuses a key, fix its mode:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_* ~/.ssh/config ~/.ssh/known_hosts
chmod 644 ~/.ssh/*.pub
```

### First connection to a new host (`authenticity of host can't be established`)

This prompt is normal and unrelated to the ownership bug above: the host key of
the server is not in `~/.ssh/known_hosts` yet. Answer once — the key is then
stored for that user. To check it out-of-band first, compare the fingerprint
with the one published by the remote (for GitHub:
<https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints>):

```bash
ssh-keyscan github.com 2>/dev/null | ssh-keygen -lf -
```

A common way to avoid the prompt is declaring the host keys in
`programs.ssh.knownHosts` (they land in `/etc/ssh/ssh_known_hosts`), but that
would put third-party key material in this public repository, so we rely on the
per-user `known_hosts` instead.

### Rule of thumb

Never run an SSH-dependent command with `sudo`. `sudo` is for system
administration (`nixos-rebuild`, `systemctl`, editing `/etc`), not for `git`,
`ssh`, `ssh-keygen` or `gh` — those must run as `zipang` so that keys,
`known_hosts` and `~/.config` stay user-owned.
