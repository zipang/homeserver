# Agent Browser Automation (agent-browser)

## Overview

[`agent-browser`](https://github.com/vercel-labs/agent-browser) is Vercel Labs'
browser automation CLI for AI agents: it opens pages, returns them as a compact
accessibility tree with `@e1` style refs, and acts on those refs one shell
command at a time. It drives Chromium over CDP through a per-session background
daemon.

It is configured in **`modules/programs/agents.nix`** and comes from the
`pkgs-unstable` package set (the package does not exist in `nixos-25.11`).

Related pages: [Chromium](./chromium.md), [AI Coding Agents](./agents.md).

### Why not `bun install -g agent-browser`?

The upstream instructions are `npm install -g agent-browser` followed by
`agent-browser install` (download Chrome for Testing). On SKYLAB that route
fails or rots for four independent reasons:

| Problem | Consequence |
| --- | --- |
| `~/bun/install/global` is **outside** the Nix store, so a `nixos-rebuild` / `nix gc` leaves it alone — but nothing in the repo reproduces it | No version pin, no review, lost after a home-directory wipe or a reinstall. It is "manual state that happens to survive upgrades", not a package. |
| Bun **blocks lifecycle scripts** of dependencies by default (the package's own wrapper source mentions this: *"when using bun which blocks lifecycle scripts by default"*) | The `postinstall` that downloads the `agent-browser-linux-x64` release asset never runs, so `~/.bun/bin/agent-browser` → JS wrapper → `Error: No binary found for linux-x64`. |
| Even when the script runs, Bun's shim points at `bin/agent-browser.js`, whose shebang is `#!/usr/bin/env node` | SKYLAB has `bun` but **no `node`**, so the shim dies with `env: 'node': No such file or directory`. Upstream only rewrites the symlink to the native binary by asking `npm prefix -g` — meaningless for a Bun global install. |
| The downloaded binary is glibc-linked with interpreter `/lib64/ld-linux-x86-64.so.2` (verified with `readelf -d` on v0.41.2) | It only runs via `programs.nix-ld`; a moving target that breaks silently when NixOS updates the glibc shim. Likewise `agent-browser install --with-deps` calls `apt`/`dnf`, which do not exist here. |

The declarative package solves all four: nixpkgs builds the Rust CLI from source
(dashboard embedded, `which`/`/bin/sleep` calls patched to store paths) and
ships `skills/` + `skill-data/` next to `bin/` so `agent-browser skills` works.

**Persistence answer**: `bun install -g` *does* survive NixOS upgrades (it lives
in `$HOME`), but it is not a supported install on NixOS and it does not survive
`~/.bun` removal, a new machine, or a changed Bun version with a different
global prefix layout. Use the Nix package instead and get upgrades through
`update-nix`.

## Configuration Reference

* Nixpkgs package (unstable only):
  [`pkgs/by-name/ag/agent-browser`](https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/by-name/ag/agent-browser)
* Package search: <https://search.nixos.org/packages?channel=unstable&query=agent-browser>
* Upstream docs: <https://agent-browser.dev> · [Installation](https://agent-browser.dev/installation) · [Configuration](https://agent-browser.dev/configuration) · [Commands](https://agent-browser.dev/commands)
* Chromium module options: [`security.chromiumSuidSandbox.enable`](https://search.nixos.org/options?channel=25.11&query=chromiumSuidSandbox)

## Full Configuration Template

```nix
# modules/programs/agents.nix
{ config, lib, pkgs, pkgs-unstable, inputs, ... }:

{
  environment.systemPackages = [
    # Native Rust CLI, built from source by nixpkgs-unstable.
    pkgs-unstable.agent-browser

    # The browser it drives (installed system-wide in modules/system/core.nix).
    pkgs.chromium
  ];

  # Skip `agent-browser install` (Chrome for Testing download) entirely and use
  # the Nix-packaged Chromium. sessionVariables is PAM-backed, so it also
  # reaches non-interactive SSH sessions such as Orca's agent shells.
  environment.sessionVariables = {
    AGENT_BROWSER_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
  };
}
```

The variable can be overridden per session with the `--executable-path` flag, or
permanently in `~/.agent-browser/config.json`:

```json
{ "executablePath": "/run/current-system/sw/bin/chromium" }
```

## Operational Guides

### First run

```bash
agent-browser open https://skylab.localhost
agent-browser snapshot -i          # interactive elements with @e1 refs
agent-browser click @e1
agent-browser get url
agent-browser close
```

The browser binary must be reachable; confirm it is the Nix one:

```bash
echo "$AGENT_BROWSER_EXECUTABLE_PATH"   # /nix/store/...-chromium-.../bin/chromium
```

### Agent skill (per harness)

The CLI ships versioned skills so the instructions always match the installed
binary — never copy them out of `node_modules`:

```bash
agent-browser skills list
agent-browser skills get core            # the core loop: refs, waiting, workflows
agent-browser skills get core --ref commands
```

Or install the thin discovery stub into an agent harness:

```bash
npx skills add vercel-labs/agent-browser
```

### Sessions and state

```bash
agent-browser --session work open https://immich.skylab.localhost
agent-browser --session work snapshot -i
agent-browser session list
agent-browser close --all
```

The daemon exits on its own after one hour of inactivity. Per-session state
cookies/auth live in `~/.agent-browser/`; profile data (Chromium user-data-dir)
lives in `~/.cache/agent-browser/` — not in the Nix store, so it is writable.

### Screenshots and PDFs

```bash
agent-browser open https://nextcloud.skylab.localhost
agent-browser screenshot /tmp/nextcloud.png
agent-browser pdf /tmp/nextcloud.pdf
```

### Use an already-running Chromium (CDP)

Useful when you already have a remote-debugging Chromium or a container:

```bash
chromium --headless --remote-debugging-port=9222 --user-data-dir=/tmp/cdp &
agent-browser --cdp 9222 open example.com
```

### MCP server for MCP clients

```bash
agent-browser mcp          # stdio MCP server
```

## Headless Operations & Troubleshooting

### Diagnostics

```bash
agent-browser doctor                    # full install + launch test
agent-browser doctor --offline --quick  # local checks only
agent-browser doctor --fix              # destructive repairs (runs install if Chrome missing)
agent-browser --version
readlink -f "$(command -v agent-browser)"   # must be /nix/store/...
```

### `Error: No binary found for linux-x64`

You are running a leftover `bun install -g` copy (postinstall blocked, so the
native binary was never fetched). Remove it and use the Nix package:

```bash
bun pm ls -g | grep agent-browser
rm ~/.bun/bin/agent-browser
hash -r
command -v agent-browser    # /run/current-system/sw/bin/agent-browser
```

### `exec: node: not found` / `env: 'node'`

Same cause: the JS wrapper is on `PATH` instead of the native binary. See above.

### `Failed to launch browser` / `browserType.launch: spawn ... ENOENT`

`AGENT_BROWSER_EXECUTABLE_PATH` is unset (e.g. inside a shell that did not get
the PAM environment) or points at a garbage-collected store path.

```bash
export AGENT_BROWSER_EXECUTABLE_PATH="$(command -v chromium)"
agent-browser doctor --offline
```

### Chromium sandbox errors

NixOS disables Chromium's setuid sandbox by default and relies on the user
namespace sandbox. If launches fail with namespace errors, enable the setuid
sandbox and rebuild:

```nix
security.chromiumSuidSandbox.enable = true;
```

See [Chromium](./chromium.md#the-sandbox-on-nixos).

### `agent-browser install --with-deps` fails

Expected. That command shells out to `apt`/`dnf` to install browser libraries;
NixOS has neither. It is unnecessary here — the nixpkgs Chromium already has its
dependencies in its wrapper.

### Daemon looks stale after an upgrade

After `update-nix`, a running daemon may be on an older protocol version. The
`doctor` output reports version-mismatched daemons; `doctor --fix` closes them
and cleans `.sock`/`.pid`/`.version` sidecars. Manual equivalent:

```bash
agent-browser close --all
ls -la ~/.agent-browser/ | grep -E 'sock|pid|version'
```
