# Copyparty — Browser-based File Sharing Hub

## Overview

Copyparty is an always-on HTTP file server: any device on the local network
(phone, laptop, tablet) can upload files to the Skylab drop boxes from a plain
web browser - no app, no account, no password.

The security model:

| Surface | Reachable from | Authentication |
|---|---|---|
| `https://copyparty.<privateDomain>/` - volume picker page | LAN (via Nginx TLS) | **None** - anonymous |
| `/buzz` and `/woody` volumes (read-write) | LAN (via Nginx TLS) | **None** - anonymous, read-write |
| Full UI + admin console (gear icon) | LAN and SSH tunnel | **None** - but no file access without a volume permission |

Both pool roots are **anonymous read-write** (`rw = "*"`): anyone on the LAN
can browse, upload and download. Move/delete operations are not included in
`rw` - they stay terminal-only (SSH / SFTP / Samba / NFS).

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

    # No accounts: no password authentication on this service.
    # No volume at "/" -> copyparty serves a picker page listing the volumes.
    volumes = {
      "/buzz" = {                # anonymous read-write share (BUZZ pool)
        path = "/share/Storage/BUZZ";
        access = { rw = "*"; };
      };

      "/woody" = {               # anonymous read-write share (WOODY pool)
        path = "/share/Storage/WOODY";
        access = { rw = "*"; };
      };
    };
  };

  # USB pools use 'nofail' + automount; the upstream unit bind-mounts the
  # volume paths and would fail to start if a pool is not mounted yet
  systemd.services.copyparty.unitConfig.RequiresMountsFor = [
    "/share/Storage/BUZZ"
    "/share/Storage/WOODY"
  ];

  # TLS vhost: full proxy per upstream recommendation (contrib/nginx) -
  # file exposure is controlled by the copyparty volumes, not by Nginx
  services.nginx.virtualHosts."copyparty.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:3923";
      proxyWebsockets = true;
      extraConfig = ''
        # Recommended by upstream for fast uploads/downloads
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_buffers 32 8k;
        proxy_buffer_size 16k;
        proxy_busy_buffers_size 24k;
      '';
    };
  };
}
```

## Operational Guides

### Upload files from any device (LAN)

1. Open `https://copyparty.<privateDomain>/` in any browser on the local
   network: the picker page lists the available drop targets (`buzz`,
   `woody`). Open one, or go directly to
   `https://copyparty.<privateDomain>/buzz`.
2. Accept the self-signed certificate warning if the mkcert CA is not
   installed on that device (see [Security & SSL Setup](./security.md)).
3. Drag & drop files: uploads are **resumable**, which makes them reliable
   even from phones on flaky Wi-Fi.
4. Dropped files land in `/share/Storage/BUZZ` or `/share/Storage/WOODY`
   owned by `zipang:users`. Both volumes are read-write, so files can also
   be browsed and downloaded back from the browser.

Command-line test from a LAN client:

```bash
curl -k -T myfile.jpg "https://copyparty.<privateDomain>/buzz/"
```

### Access the full UI via SSH tunnel

The same web UI is reachable on the LAN, but for privacy (readable
`?admin`/config panes, session lists) you can also open it through a tunnel:

```bash
ssh -L 3923:127.0.0.1:3923 zipang@skylab
# then open: http://127.0.0.1:3923
```

From there you can open the admin console (gear icon) to review the live
configuration and logs. Note: there is intentionally no web browsing of
`/share` - file management is done over SFTP / Samba / NFS / terminal.

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
curl -k https://copyparty.<privateDomain>/
```

Common issues:

- **FATAL ERROR: cannot load util.js ... broken reverse-proxy**: the proxy
  must forward **all** app-level paths (`location /`), not just `/drop/*` -
  the UI loads its assets from global paths like `/.cpr/util.js`.

- **Service fails to start after boot with a USB pool disconnected**:
  `RequiresMountsFor` makes the service wait for the mounts, but `nofail`
  means the system can boot without them. Plug the pool back in, then:
  ```bash
  sudo systemctl restart copyparty.service
  ```
- **Uploads rejected by Nginx (413)**: the global `client_max_body_size`
  is set to `10G` in `modules/services/nginx.nix`; raise it there if needed.
  Copyparty itself chunks uploads, so this limit is rarely hit.
