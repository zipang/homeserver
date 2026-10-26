# AI Coding Agents — OpenCode, Pi & Orca Remote Integration

## Overview

This document outlines the investigation, NixOS installation strategy, and step-by-step setup plan for running two AI coding agent harnesses on **SKYLAB** (`opencode` and `pi`), and controlling them remotely from machines on the local network (or via Netbird VPN) — either via **Orca** (`onorca.dev`) as an SSH Target or directly over an **SSH session**.

Both `opencode` and `pi` have built-in session management and persistence (allowing you to switch between or resume multiple sessions natively without needing a terminal multiplexer).

**Relevant module paths**:
- `flake.nix` — Flake inputs for `nixpkgs-unstable` (for OpenCode V2) and `pi` (upstream official flake).
- `modules/programs/agents.nix` — Declarative installation of `opencode`, `pi`, supporting CLI tools (`ripgrep`, `fd`, `fzf`, `gh`), and `nix-ld` dynamic linker compatibility for Orca's remote server runtime.

### Architecture & Remote Control Matrix

| Tool / Mode | Role on SKYLAB | How Clients Connect (LAN / VPN) | Session Management |
|---|---|---|---|
| **OpenCode** | Agent harness (`opencode`) + per-user background server | 1. **Orca** (SSH Target)<br>2. **Direct SSH** (`ssh zipang@skylab`)<br>3. **Web UI / App** (`opencode pair` over SSH port forward) | Background server (`opencode service`) persists all sessions in `~/.local/share/opencode/opencode.db`; switch sessions inside the TUI or CLI |
| **Pi** | Terminal agent harness (`pi`) | 1. **Orca** (SSH Target — auto-setup, hooks, native chat)<br>2. **Direct SSH** (`ssh zipang@skylab`) | Saves sessions automatically per folder in `~/.pi/agent`; resume or switch via `pi --continue` or `/resume` |
| **Orca (SSH Target)** | Auto-deploys its own managed Node server (`orcad`) over SSH into `~/.orca` | Orca Desktop on client machines connects over SSH (`zipang@skylab`) | Remote PTY and structured chat sessions live on SKYLAB's managed Orca server and survive client disconnects/sleep |

---

## Configuration Reference

Because AI agent harnesses evolve rapidly, we combine official NixOS 25.11 options with upstream flakes and `nixpkgs-unstable`:

- **NixOS 25.11 Options Search**:
  - [`programs.nix-ld`](https://search.nixos.org/options?channel=25.11&query=programs.nix-ld) — Runs unpatched dynamic binaries (required by Orca's auto-deployed `orcad` Node runtime and prebuilt native agent extensions on NixOS).
  - [`users.users.<name>.linger`](https://search.nixos.org/options?channel=25.11&query=users.users.%3Cname%3E.linger) — Keeps user background processes (OpenCode's background service and Orca's managed remote server) running after SSH logout.
  - [`services.openssh`](https://search.nixos.org/options?channel=25.11&query=services.openssh) — TCP forwarding and multiplexing settings for Orca SSH worktrees.
- **Upstream & Package References**:
  - **OpenCode**: [OpenCode V2 Docs](https://opencode.ai/v2/docs/) · [CLI & Sessions](https://opencode.ai/v2/docs/cli/commands/) · [Nixpkgs `opencode` package](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/op/opencode/package.nix)
  - **Pi**: [Pi Quickstart](https://pi.dev/docs/latest/quickstart) · [Official `earendil-works/pi` Flake (`stable`)](https://github.com/earendil-works/pi/blob/stable/flake.nix) · [Nixpkgs `pi-coding-agent` package](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/pi/pi-coding-agent/package.nix)
  - **Orca**: [Ways to Run Orca](https://www.onorca.dev/docs/ways-to-run) · [SSH Worktrees](https://www.onorca.dev/docs/ssh) · [Work on a Remote Machine over SSH](https://www.onorca.dev/docs/recipes/remote-worktrees)

---

## NixOS Installation Investigation: Which Process is Best Suited?

We evaluated four ways to install `opencode` and `pi` on SKYLAB (NixOS 25.11):

| Method | OpenCode | Pi (`pi-coding-agent`) | Verdict for SKYLAB |
|---|---|---|---|
| **1. `nixos-25.11` (Stable Nixpkgs)** | Ships legacy **v1.1.14**. Misses V2 architecture (`opencode service`, `opencode pair`, native Orca V2 hooks). | **Not packaged** in 25.11. | **Not recommended** (outdated / missing). |
| **2. `nixpkgs-unstable` + Upstream Flakes** | `nixpkgs-unstable` ships **OpenCode V2 (v2.1.x+)** with pre-hashed `node_modules` and `OPENCODE_DISABLE_AUTOUPDATE=true`. | Official `github:earendil-works/pi/stable` flake (and `nixpkgs-unstable` `pi-coding-agent` v1.4.0+) builds cleanly with `ripgrep` and `fd` wrapped. | **Recommended (Primary)**: 100% declarative, reproducible, in `/run/current-system/sw/bin` so both interactive SSH sessions and Orca's non-interactive SSH sessions always find `opencode` and `pi` in `PATH`. |
| **3. `devbox global`** | Pulls from Nixpkgs catalogs on demand (`devbox global add opencode`). | Can install via Nix flake reference (`devbox global add github:earendil-works/pi/stable`). | **Alternative** if you want to bump agent versions without running `nixos-rebuild`, but requires sourcing Devbox in non-interactive SSH shells for Orca to detect the CLIs. |
| **4. Imperative (`curl \| sh` or `npm -g`)** | Downloads dynamically linked Linux binaries that fail on NixOS without `nix-ld`. | Installs into `~/.pi` or npm prefix; breaks declarative state. | **Avoid** on NixOS. |

### Why `programs.nix-ld` is Mandatory for Orca SSH Targets on NixOS

When you connect Orca from a client machine to SKYLAB over SSH, Orca automatically sets up its own **Managed Orca Server** (`orcad`) on SKYLAB. It downloads a pinned, prebuilt standard Linux Node.js runtime and native PTY/file-watcher modules into your home directory.

On standard NixOS, dynamically linked prebuilt Linux binaries fail immediately with `ENOENT: no such file or directory` because `/lib64/ld-linux-x86-64.so.2` does not exist. Enabling `programs.nix-ld` in NixOS creates this compatibility shim and exposes standard libraries (`glibc`, `libstdc++`, `zlib`, `openssl`, `libxcb`), allowing Orca's managed SSH server and any prebuilt agent extensions to work out of the box without manual patching.

---

## Full Configuration Template

### 1. Flake Inputs (`flake.nix`)

Add `nixpkgs-unstable` and the official `pi` flake input so SKYLAB can pull V2 `opencode` and the latest stable `pi` while keeping the rest of the system on `nixos-25.11`:

```nix
{
  description = "SKYLAB Homelab NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # Unstable channel for fast-moving AI agent harnesses (OpenCode V2)
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Official Pi coding agent flake (tracks latest stable release)
    pi.url = "github:earendil-works/pi/stable";

    sops-nix.url = "github:Mic92/sops-nix";
    snacks-nvim = { url = "github:folke/snacks.nvim"; flake = false; };
    copyparty.url = "github:9001/copyparty";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, pi, sops-nix, copyparty, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in {
      nixosConfigurations.SKYLAB = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs pkgs-unstable; };
        modules = [
          sops-nix.nixosModules.sops
          copyparty.nixosModules.default
          ./hosts/SKYLAB/configuration.nix
        ];
      };
    };
}
```

### 2. Agent Harnesses & Orca Compatibility Module (`modules/programs/agents.nix`)

Create `modules/programs/agents.nix` and import it in `hosts/SKYLAB/configuration.nix`:

```nix
{ config, pkgs, pkgs-unstable, inputs, ... }:

{
  # 1. Install OpenCode V2, Pi, and required search/git helpers system-wide.
  # Putting them in environment.systemPackages places them in /run/current-system/sw/bin,
  # ensuring Orca's non-interactive SSH sessions discover them automatically.
  environment.systemPackages = [
    # OpenCode V2 from nixpkgs-unstable
    pkgs-unstable.opencode

    # Pi coding agent from official upstream flake
    # (Alternative: pkgs-unstable.pi-coding-agent)
    inputs.pi.packages.${pkgs.system}.default

    # Essential CLI tools used by OpenCode, Pi, and Orca worktrees
    pkgs.git
    pkgs.gh          # GitHub CLI (used by Orca for PRs, issues, and checks)
    pkgs.ripgrep     # Fast code search
    pkgs.fd          # Fast file finder
    pkgs.fzf         # Fuzzy finder
    pkgs.jq          # JSON processor for CLI scripting
  ];

  # 2. Enable nix-ld so Orca's auto-deployed Managed Server (orcad / pinned Node.js)
  # and prebuilt native agent extensions (.node binaries) run seamlessly on NixOS.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      zstd
      openssl
      curl
      libxcb
      util-linux
      icu
    ];
  };

  # 3. Keep user background services (OpenCode background daemon & Orca's managed SSH server)
  # alive after SSH disconnect.
  users.users.${config.server.mainUser}.linger = true;

  # 4. Ensure OpenSSH allows port forwarding and multiplexing (required by Orca SSH targets)
  services.openssh.settings = {
    AllowTcpForwarding = "yes";
    MaxSessions = 20; # Orca multiplexes several channels over one SSH connection
  };
}
```

---

## Operational Guides

### 1. Authenticating OpenCode and Pi on SKYLAB

**Important**: Remote sessions (both direct SSH and Orca SSH worktrees) use **SKYLAB's** credentials and environment, not your client laptop's credentials. Log in once on SKYLAB over SSH:

#### Authenticate OpenCode
```bash
ssh zipang@skylab

# Interactive provider login (Anthropic, OpenAI, OpenRouter, Google, etc.)
opencode auth login

# Verify configured providers
opencode auth list
```
*(Credentials are stored in `~/.local/share/opencode/auth.json`, and global settings live in `~/.config/opencode/opencode.json`.)*

#### Authenticate Pi
```bash
ssh zipang@skylab

# Start Pi in any directory and run the built-in login command
pi
# Inside Pi TUI:
/login
/model
```
*(Pi stores credentials in `~/.pi/agent/auth.json` and user configuration in `~/.pi/agent/settings.json`.)*

---

### 2. Controlling SKYLAB Agents Remotely via Orca (SSH Target)

Orca (`onorca.dev`) supports both **OpenCode** and **Pi** natively out of the box (with auto-setup, status reporting, and structured native chat). Using **SSH Target** mode, the Orca desktop app runs on your local machine while repositories, git worktrees, terminals, `opencode`, and `pi` execute on SKYLAB.

1. **Verify SSH access** from your client machine:
   ```bash
   ssh zipang@skylab
   ```
2. **Add SKYLAB as an SSH Target in Orca** (on your client machine):
   - Open **Orca → Settings → SSH → Add Target**.
   - Pick `skylab` from the **OpenSSH config** picker (or enter Host: `skylab` / LAN IP / Netbird IP `100.64.x.y`, User: `zipang`, Port: `22`).
   - Click **Test** to verify connectivity, then **Save**.
   - *First connect*: Orca automatically sets up its **Managed Orca Server** on SKYLAB (powered by `programs.nix-ld`).
3. **Create a Remote Worktree & Launch Agents**:
   - Add a repository in Orca (selecting the `skylab` SSH target as its location) or create a new worktree and select `skylab` under **Run on**.
   - Open a new Agent tab in that worktree and select **OpenCode** or **Pi** from the agent picker.
   - **Disconnect survival**: Closing the Orca app or putting your laptop to sleep does **not** kill your remote sessions. They continue running on SKYLAB's managed Orca server (`users.users.zipang.linger = true`), and Orca reattaches to your live tabs and scrollback when you reconnect.

---

### 3. Accessing OpenCode & Pi Directly over SSH

When you want to use `opencode` or `pi` directly from a terminal on any LAN machine without Orca, simply connect via SSH and use each agent's built-in session management:

#### Using OpenCode over SSH
```bash
ssh zipang@skylab
cd ~/homeserver

# Launch the TUI (automatically connects to your user's shared background server)
opencode

# Or list and manage existing sessions from the CLI:
opencode session list

# Continue the most recent session directly from the CLI or Mini UI:
opencode mini --continue
```

If you also want to open OpenCode's built-in Web UI in your local browser over SSH:
```bash
# Forward OpenCode's default localhost port (49374) and generate a one-time login link:
ssh -L 49374:127.0.0.1:49374 zipang@skylab "opencode pair"
```

#### Using Pi over SSH
```bash
ssh zipang@skylab
cd ~/homeserver

# Start a new Pi session in the current folder
pi

# Or resume the most recent session for this folder:
pi --continue

# Inside Pi, switch between any saved sessions at any time:
/resume
```

---

## Implementation Plan (Step-by-Step)

1. **Step 1 — Update `flake.nix`** *(done)*:
   `nixpkgs-unstable` and `pi` (`github:earendil-works/pi/stable`) are declared as inputs, and `pkgs-unstable` + `inputs` are passed to the modules via `specialArgs`.
2. **Step 2 — Create `modules/programs/agents.nix`** *(done)*:
   Installs `pkgs-unstable.opencode`, `inputs.pi.packages.${pkgs.system}.default`, `gh`, `ripgrep`, `fd`, `fzf`, `jq`, enables `programs.nix-ld`, sets `linger = true` for `mainUser` and relaxes the OpenSSH forwarding limits.
3. **Step 3 — Register the Module** *(done)*:
   `../../modules/programs/agents.nix` is imported in `hosts/SKYLAB/configuration.nix`.
4. **Step 4 — Apply on SKYLAB**:
   Run `update-nix` on SKYLAB (the first build of Pi from source takes a few minutes), then authenticate:
   ```bash
   opencode auth login
   pi    # then /login inside the TUI
   ```
5. **Step 5 — Pair Orca**:
   On each client machine, add `skylab` under **Settings → SSH** in Orca, click **Test**, then create a remote worktree with **Run on → skylab** and launch `OpenCode` or `Pi`.

### Post-deployment verification

```bash
# Binaries must resolve from a non-interactive SSH shell (this is what Orca uses)
ssh zipang@skylab "which opencode pi && opencode --version && pi --version"

# nix-ld shim present (required by Orca's managed server)
ssh zipang@skylab "ls -l /run/current-system/sw/share/nix-ld/lib/ld.so"

# User lingering enabled (sessions survive logout)
ssh zipang@skylab "loginctl show-user zipang --property=Linger"
```

---

## Headless Operations & Troubleshooting

### Verify Installed Versions & Paths
Confirm that non-interactive SSH shells (used by Orca) can resolve both agent binaries and `nix-ld`:

```bash
# Test from a remote LAN machine over non-interactive SSH
ssh zipang@skylab "which opencode pi rg fd gh && opencode --version && pi --version"

# Verify nix-ld dynamic linker shim is active on SKYLAB
ssh zipang@skylab "ls -la /run/current-system/sw/share/nix-ld/lib/ld.so"
```

### OpenCode Service & Daemon Management
```bash
# Check the per-user background OpenCode service status and listening URL
opencode service status

# Verify API health of the background server
opencode api get /api/info

# Restart the per-user background server if stuck
opencode service restart

# Follow OpenCode application logs in real time
tail -f ~/.local/share/opencode/log/opencode.log
```

### Pi Session & Package Management
```bash
# Resume the most recent Pi session in the current folder
pi --continue

# Refresh the cached model catalog from pi.dev
pi update --models

# Inspect Pi configuration and session storage
ls -la ~/.pi/agent/
```
*(Note: Because Pi is installed via Nix, `pi update` will not self-mutate the binary; update Pi declaratively via `nix flake update pi` and `update-nix`.)*

### Orca Managed SSH Server Troubleshooting
If Orca on your laptop connects over SSH but remote terminals fail to spawn:
1. Check **Settings → SSH Hosts** and **Settings → Managed servers** in the Orca desktop UI.
2. From your client terminal, inspect or recover the managed server environment on SKYLAB:
   ```bash
   orca environment list --json
   orca environment status --environment skylab --json
   orca environment recover --environment skylab --json
   ```
3. If a prebuilt binary inside `~/.orca` complains about a missing shared library (`.so`), check which library is needed with `ldd` and add the corresponding package to `programs.nix-ld.libraries` in `modules/programs/agents.nix`.
