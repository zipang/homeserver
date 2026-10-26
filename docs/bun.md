# Bun Runtime

## Overview

Bun is the JavaScript/TypeScript runtime used by this repository's tooling
(`scripts/av1-converter`, `scripts/deploy-secret.ts`) and installed system-wide
for interactive use.

It is configured in **`modules/system/core.nix`** and comes from the
`pkgs-unstable` package set, which is passed to every module through
`specialArgs` in `flake.nix`.

### Why the unstable channel?

`nixos-25.11` ships **Bun 1.3.3**, while upstream is already on the 1.4.x
series. Because Bun is a fast-moving runtime, it is pulled from
`nixpkgs-unstable` (currently **1.4.2**) instead of the stable channel. The rest
of the system remains on `nixos-25.11`; only this single package is taken from
the unstable set.

```nix
# modules/system/core.nix
{ config, pkgs, pkgs-unstable, ... }:
{
  environment.systemPackages = with pkgs; [
    # ...
    pkgs-unstable.bun
  ];
}
```

## Configuration Reference

* Nixpkgs package definition:
  [`pkgs/by-name/bu/bun`](https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/by-name/bu/bun)
* Package contents (binaries, version per channel):
  <https://search.nixos.org/packages?channel=unstable&query=bun>
* Bun upstream documentation: <https://bun.sh/docs>

## Full Configuration Template

```nix
{ config, pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = [
    # Latest Bun, from the unstable package set (system-wide, so it is also
    # available to root and to non-interactive SSH sessions).
    pkgs-unstable.bun
  ];
}
```

Any script or wrapper that must run the same runtime should reference the very
same attribute, e.g. in `modules/programs/media-tools.nix`:

```nix
makeWrapper ${pkgs-unstable.bun}/bin/bun $out/bin/av1-converter \
  --add-flags $out/share/av1-converter/av1-converter.js
```

## Operational Guides

### Check the installed version

```bash
bun --version
```

### Upgrade Bun

```bash
update-nix
```

`update-nix` performs `nix flake update`, so `nixpkgs-unstable` (and therefore
Bun) moves to the newest revision of the unstable channel, then rebuilds and
switches the system.

To upgrade Bun only, without touching the other inputs:

```bash
nix flake lock --update-input nixpkgs-unstable
sudo nixos-rebuild switch --impure --flake .#SKYLAB
```

### Use a different Bun version for one project

Pin it locally with Devbox rather than on the system:

```bash
devbox init
devbox add bun@1.3.3
devbox shell
```

Note that Devbox also resolves `bun` from Nixpkgs, so the binary remains
read-only: pinning gives you a *different* version, not a self-updatable one.
See [Devbox](./devbox.md).

## Headless Operations & Troubleshooting

### `error: Failed to move new version of Bun to /nix/store/.../bin/bun to EROFS`

This is **expected**, not a bug. `bun upgrade` downloads a new binary and then
`rename()`s it over the running executable. On NixOS, `/nix/store` is a
read-only filesystem (`EROFS`) and every package path is content-addressed and
immutable — nothing may be modified in place. The same is true for
`npm install -g`, `pip install --upgrade`, `rustup self update`, etc.

Use the declarative upgrade path instead:

```bash
update-nix                      # upgrades everything, including Bun
```

or, without a full system rebuild:

```bash
nix shell nixpkgs#bun          # try the latest Bun from the unstable channel
```

### `bun: command not found`

* Check that the package is still listed in `modules/system/core.nix` and
  imported by `hosts/SKYLAB/configuration.nix`.
* Check the profile link:
  ```bash
  ls -l /run/current-system/sw/bin/bun
  ```
* Non-interactive shells (including Orca's SSH sessions) use the system PATH,
  which always contains `/run/current-system/sw/bin`.

### Running the AV1 converter

`av1-converter` wraps the bundled script with this exact Bun runtime, so it
never depends on your interactive `PATH`:

```bash
systemd-run --user --unit=av1-conversion --collect \
  bun scripts/av1-converter/src/index.ts --dir /share/Storage/Movies
journalctl --user -u av1-conversion -f
```

See [AV1 Converter](./media-converter.md) for details.

### Verify after a rebuild

```bash
bun --version
readlink -f "$(command -v bun)"   # must be a /nix/store/... path
```
