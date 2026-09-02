# Copyparty — Browser-based File Sharing Hub

## Overview

Copyparty is an always-on HTTP file server: any device on the local network
(phone, laptop, tablet) can upload files to the Skylab drop boxes from a plain
web browser - no app, no account, no password.

The security model is split in two:

| Surface | Reachable from | Authentication |
|---|---|---|
| `https://copyparty.<privateDomain>/drop/buzz` and `/drop/photos` | LAN (via Nginx TLS) | **None** - anonymous, upload-only |
| Full UI on `127.0.0.1:3923` (browse `/share`, admin console) | SSH tunnel only | **SSH keys** (enforced by sshd) |

Anonymous users can push files but never list or download what was dropped.
File management stays in the terminal (SSH / Samba / NFS).

**Module paths**

- `modules/services/copyparty.nix` - our service wrapper (volumes, Nginx vhost)
- The `services.copyparty` options are **not in nixpkgs**: they come from the
  official NixOS module shipped in the
  [copyparty flake](https://github.com/9001/copyparty/blob/hovudstraum/contrib/nixos/modules/copyparty.nix),
  registered as a flake input in `flake.nix`. The application package itself
  (`pkgs.copyparty`) comes from our pinned nixpkgs 25.11.

## Configuration Reference

Since the options are provided by the upstream flake, they do not appear in the
[NixOS options search](https://search.nixos.org/options?channel=25.11&query=services.copyparty).
The canonical references are:

- Upstream NixOS module source: [contrib/nixos/modules/copyparty.nix](https://github.com/9001/copyparty/blob/hovudstraum/contrib/nixos/modules/copyparty.nix)
- Upstream documentation: [copyparty GitHub](https://github.com/9001/copyparty)
  (see the README section *config file example* for volume / access syntax)

Key options:

- `services.copyparty.enable` - start the systemd service
- `user` / `group` - OS account running the service (owns received files)
- `settings` - the `[global]` section of the copyparty config (`i` = bind
  address, `p` = port). **Note**: `settings` replaces the module defaults
  (`no-reload`, `hist`) - re-declare them if you override it.
- `volumes.<url>` - map a URL path to a server directory, with `access`
  rules: `r` (read), `w` (upload-only, no listing), `rw`, `rm`...
- `accounts.<name>.passwordFile` - optional login accounts (we use none)

## Full Configuration Template

```nix
{ config, pkgs, ... }:

{
  services.copyparty = {
    enable = true;
    user = "zipang";
    group = "users";

    settings = {
      # Loopback only: LAN goes through the Nginx TLS proxy,
      # full UI is reached via SSH tunnel
      i = "127.0.0.1";
      p = 3923;
      # Module defaults must be re-declared when overriding settings
      no-reload = true;
      hist = "/var/cache/copyparty";
    };

    # No accounts: no password authentication on this service
    volumes = {
      "/" = {                    # browse the whole share tree
        path = "/share";         # (SSH tunnel only - Nginx denies it on LAN)
        access = { r = "*"; };
      };

      "/drop/buzz" = {           # anonymous upload-only drop box
        path = "/share/Storage/BUZZ";
        access = { w = "*"; };
      };

      "/drop/photos" = {         # anonymous upload-only drop box
        path = "/share/Storage/WOODY/photos";
        access = { w = "*"; };
      };
    };
  };

  # USB pools use 'nofail' + automount; the upstream unit bind-mounts the
  # volume paths and would fail to start if a pool is not mounted yet
  systemd.services.copyparty.unitConfig.RequiresMountsFor = [
    "/share/Storage/BUZZ"
    "/share/Storage/WOODY/photos"
  ];

  # TLS vhost: only the drop boxes are exposed to the LAN
  services.nginx.virtualHosts."copyparty.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      extraConfig = ''deny all;'';
    };

    locations."/drop/" = {
      proxyPass = "http://127.0.0.1:3923";
      proxyWebsockets = true;
    };
  };
}
```

## Operational Guides

### Upload files from any device (LAN)

1. Open `https://copyparty.<privateDomain>/drop/buzz` (or `/drop/photos`)
   in any browser on the local network.
2. Accept the self-signed certificate warning if the mkcert CA is not
   installed on that device (see [Security & SSL Setup](./security.md)).
3. Drag & drop files: uploads are **resumable**, which makes them reliable
   even from phones on flaky Wi-Fi.
4. Dropped files land in `/share/Storage/BUZZ` or `/share/Storage/WOODY/photos`
   owned by `zipang:users`. Senders cannot list or read them back.

Command-line test from a LAN client:

```bash
curl -k -T myfile.jpg "https://copyparty.<privateDomain>/drop/buzz/"
```

### Access the full UI via SSH tunnel

The browse/admin interface only listens on loopback. From a machine whose SSH
key is authorized on Skylab:

```bash
ssh -L 3923:127.0.0.1:3923 zipang@skylab
# then open: http://127.0.0.1:3923
```

From there you can browse `/share`, inspect received files, and open the admin
console (gear icon) to review the live configuration and logs.

### Manage received files

Use the terminal over SSH, or the existing Samba / NFS shares - the dropped
files are regular files owned by `zipang:users`.

### Adding password accounts (optional)

Not used today. If you ever need a logged-in volume (e.g. remote downloads),
add accounts and grant them instead of `*`:

```nix
services.copyparty.accounts.zipang.passwordFile = "/var/lib/secrets/copyparty_zipang";
# then in a volume: access = { rw = [ "zipang" ]; };
```

The password file must exist on the host before `nixos-rebuild` (create it
manually with restrictive permissions: `sudo install -m 600 /dev/null /var/lib/secrets/copyparty_zipang`).

## Headless Operations & Troubleshooting

```bash
# Logs monitoring
journalctl -u copyparty.service -f

# Status check
systemctl status copyparty.service

# Confirm the listener is loopback-only
ss -tlnp | grep 3923

# Confirm the Nginx vhost answers (from the server itself)
curl -k https://copyparty.<privateDomain>/drop/buzz/
```

Common issues:

- **Service fails to start after boot with a USB pool disconnected**:
  `RequiresMountsFor` makes the service wait for the mounts, but `nofail`
  means the system can boot without them. Plug the pool back in, then:
  ```bash
  sudo systemctl restart copyparty.service
  ```
- **Uploads rejected by Nginx (413)**: the global `client_max_body_size`
  is set to `10G` in `modules/services/nginx.nix`; raise it there if needed.
  Copyparty itself chunks uploads, so this limit is rarely hit.
- **`/` returns 403 from the LAN**: expected - the Nginx vhost only exposes
  `/drop/*`; use the SSH tunnel for anything else.
