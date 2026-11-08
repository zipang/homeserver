# Chromium

## Overview

Chromium is installed system-wide on SKYLAB as the headless-capable browser used
for automation: rendering pages to PDF/PNG, scraping, and driving tooling that
needs a real Chromium engine (OpenCode's web UI checks, screenshots, Puppeteer /
Playwright pointing at the system binary).

It is configured in **`modules/system/core.nix`** and comes from the stable
`nixos-25.11` package set.

Because the server runs in terminal mode only, Chromium is almost always used
with `--headless`. There is **no display server** (`X11`/`Wayland`) on SKYLAB, so
any non-headless invocation fails unless you forward a display over SSH.

## Configuration Reference

* Nixpkgs package definition:
  [`pkgs/by-name/ch/chromium`](https://github.com/NixOS/nixpkgs/tree/nixos-25.11/pkgs/by-name/ch/chromium)
* Package contents (version per channel):
  <https://search.nixos.org/packages?channel=25.11&query=chromium>
* Setuid sandbox option:
  [`security.chromiumSuidSandbox.enable`](https://search.nixos.org/options?channel=25.11&query=chromiumSuidSandbox)
* Chromium headless documentation: <https://developer.chrome.com/docs/chromium/headless>

## Full Configuration Template

```nix
# modules/system/core.nix
{ config, pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = with pkgs; [
    # ...
    chromium
  ];

  # optional
  security.chromiumSuidSandbox.enable = true;
}
```

## The Sandbox on NixOS

NixOS **disables Chromium's setuid sandbox by default**. The package is shipped
without a setuid `chrome-sandbox` helper, because setuid binaries cannot live in
the `nosuid`-mounted `/nix/store`. Consequently:

| Usage | Works out of the box? |
| --- | --- |
| `chromium --headless ...` | ✅ yes |
| Non-headless / rooted automation | ❌ needs a sandbox decision |

Two ways forward:

1. **Enable the setuid sandbox** (recommended if you need the sandbox):

   ```nix
   security.chromiumSuidSandbox.enable = true;
   ```

   This installs a setuid wrapper outside the store.

2. **Disable the sandbox explicitly** for trusted, local automation only:

   ```bash
   chromium --headless --no-sandbox --disable-gpu ...
   ```

   `--no-sandbox` is acceptable for one-off local page rendering. Do **not** use
   it to render untrusted content as a service, and do **not** run Chromium as
   `root` with `--no-sandbox` in a multi-user setup.

Note that `--disable-gpu` is also expected here: the NUC's GPUs (Intel HD 630,
AMD Vega M) have no active display/driver stack in a headless terminal-only
install.

## Operational Guides

### Render a page to PDF

```bash
chromium --headless --disable-gpu --no-sandbox \
  --print-to-pdf=/tmp/skylab.pdf https://skylab.localhost
```

### Take a screenshot

```bash
chromium --headless --disable-gpu --no-sandbox \
  --window-size=1440,900 \
  --screenshot=/tmp/skylab.png https://skylab.localhost
```

### Dump the DOM (quick connectivity / TLS check)

```bash
chromium --headless --disable-gpu --no-sandbox \
  --dump-dom https://immich.skylab.localhost | head -20
```

This is a convenient way to verify that an nginx vhost, a certificate issued by
our local CA, and the service behind it all line up. See [Security & SSL
Setup](./security.md) and [Nginx](./nginx.md).

### Use it from agent-browser

`agent-browser` (see [Agent Browser Automation](./agent-browser.md)) drives the
packaged Chromium through `AGENT_BROWSER_EXECUTABLE_PATH`, which is set
declaratively in `modules/programs/agents.nix`:

```bash
agent-browser open https://skylab.localhost
agent-browser snapshot -i
```

### Use it from Playwright / Puppeteer

Point the automation library at the system binary instead of downloading its own
Chromium (a download would land in a writable cache, not the Nix store, and
would silently drift from the packaged version):

```bash
export PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH="$(command -v chromium)"
# or, per call:
# chromium.launch({ executablePath: "/run/current-system/sw/bin/chromium" })
```

Remember to pass `--no-sandbox` unless `security.chromiumSuidSandbox.enable` is
set.

### Remote debugging over an SSH tunnel

The web UI and CDP are best kept bound to loopback and reached through a tunnel:

```bash
# on SKYLAB
chromium --headless --disable-gpu --no-sandbox \
  --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222 \
  about:blank &

# on the workstation
ssh -L 9222:127.0.0.1:9222 skylab
# then open http://127.0.0.1:9222/json in a local browser
```

### Profile and cache directories

Chromium writes a profile next to `$HOME` by default. For long-running jobs use
a scratch profile so the home directory does not fill up:

```bash
chromium --headless --disable-gpu --no-sandbox \
  --user-data-dir=/tmp/chromium-profile \
  --dump-dom https://nextcloud.skylab.localhost
```

## Headless Operations & Troubleshooting

### `Missing X server or $DISPLAY`

Chromium defaults to the graphical mode. Always pass `--headless` on SKYLAB:

```bash
chromium --headless --disable-gpu --no-sandbox --dump-dom about:blank
```

If you truly need a GUI, forward X11 instead (`ssh -X skylab`), which requires
`services.openssh.settings.X11Forwarding = true` and an X server on the client.

### `Failed to move to new namespace` / `clone: Operation not permitted`

The sandbox cannot start. Either enable it declaratively:

```nix
security.chromiumSuidSandbox.enable = true;
```

or run with `--no-sandbox` for trusted local use.

### `zygote_host_impl_linux.cc ... Running as root without --no-sandbox is not supported`

Chromium refuses to sandbox itself as `root`. Run it as the main user, or add
`--no-sandbox` (only for trusted content).

### `Failed to connect to the bus`

`dbus` is not installed in this terminal-only setup. It is harmless for headless
rendering; add `--disable-features=UseDBus`-style flags or simply ignore the
warning.

### `[ERROR:bus.cc] ...` / `gpu_init.cc` / `viz_main_impl.cc` noise

Expected in a headless, GPU-less environment. `--disable-gpu` keeps the noise
down; it does not affect correctness of `--dump-dom`, `--screenshot`, or
`--print-to-pdf`.

### Verify the installation

```bash
chromium --version
readlink -f "$(command -v chromium)"   # must be a /nix/store/... path
```

### Check that an update landed

```bash
sudo nixos-rebuild switch --impure --flake path:.#SKYLAB
chromium --version
```

Chromium is a fast-moving package; `update-nix` (a full `nix flake update` plus
rebuild) is the way to pick up new stable releases.
