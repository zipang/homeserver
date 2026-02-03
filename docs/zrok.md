# zrok (Self-Hosted)

## Overview
`zrok` is an open-source sharing platform built on [OpenZiti](https://openziti.io/). It allows you to securely share local services (like Nextcloud or Immich) with the public internet using encrypted tunnels and integrated OAuth (Google/GitHub) authentication.

In SKYLAB, `zrok` replaces both Cloudflare Tunnels and Authelia for public access and SSO.

- **NixOS Module**: `modules/services/zrok.nix`
- **Official Docs**: [zrok.io](https://docs.zrok.io/)

## Configuration Reference
- [zrok Self-Hosting Guide](https://docs.zrok.io/docs/guides/self-hosting/)
- [zrok OAuth Authentication](https://docs.zrok.io/docs/concepts/sharing/public/#oauth-authentication)

## OCI Containers in NixOS
In this project, we use the `virtualisation.oci-containers` NixOS option to manage `zrok`. 

### What is an OCI Container?
OCI (Open Container Initiative) is a set of industry standards for container formats and runtimes. When we speak of "OCI Containers" in NixOS, we are referring to a declarative way to run containers (typically Docker or Podman images) as **systemd services**.

### Why use OCI Containers here?
1. **Declarative Configuration**: We define the image, ports, volumes, and environment variables directly in our `.nix` files.
2. **Standard Linux Integration**: Each container becomes a standard systemd unit (e.g., `docker-zrok-controller.service`). This allows us to use standard tools like `systemctl` and `journalctl` for management.
3. **Dependency Management**: We can easily define that the `zrok-controller` must start only *after* the `ziti-controller` is ready using `dependsOn`.
4. **Reliability**: NixOS ensures that the containers are pulled and restarted automatically if the server reboots or the configuration changes.

## DNS Setup (Required)
To host your own `zrok` instance, you must configure your DNS records to point to your server's public IP.

| Type | Host / Name | Value / Target | Proxy (Cloudflare) | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **A** | `@` | `[Public IP]` | DNS Only / Proxied | Root domain |
| **CNAME** | `*` | `example.com` | **DNS Only** | Wildcard for services |
| **CNAME** | `ziti` | `example.com` | **DNS Only** | OpenZiti Controller |
| **CNAME** | `oauth` | `example.com` | DNS Only / Proxied | OAuth Redirect Handler |

> **IMPORTANT**: The `ziti` record and the wildcard `*` should ideally be set to **DNS Only** (Grey Cloud) in Cloudflare to avoid protocol interference with the OpenZiti tunnels.

## Full Configuration Template
The `zrok` configuration is managed via OCI containers. Below is the conceptual structure of the environment variables used in `sops-nix`.

### Secrets Management (Manual)
`zrok` environment files are managed manually inside `/var/lib/secrets/zrok/` to keep them outside of the Git repository.

Use the provided script to initialize them:
```bash
sudo ./scripts/generate-zrok-secrets.sh
```

- **`controller.env`**: Contains `ZROK_ADMIN_TOKEN` and `ZITI_PWD`.
- **`frontend.env`**: Contains Google OAuth credentials and the `ZROK_OAUTH_HASH_KEY`.

### Static Homepage
The `zrok.nix` module includes a local Nginx container and a `zrok-init` service that generates a basic `index.html` at `/var/www/homepage/index.html`. This is intended to be shared on the root domain (`skylab.quest`).

## Operational Guides

### Adding a New Service to zrok
To share a service like Nextcloud:
1. Ensure the service is running locally (e.g., `localhost:8080`).
2. Use the `zrok` CLI to reserve and share the service (details in Phase 3 of WIP).

### Google OAuth Configuration
1. Set the **Authorized Redirect URI** to `https://oauth.example.com/google/callback`.
2. Ensure the scope `openid email profile` is requested.

## Headless Operations & Troubleshooting

### Monitoring Logs
```bash
# Monitor OpenZiti Controller
journalctl -u docker-ziti-controller.service -f

# Monitor zrok Controller
journalctl -u docker-zrok-controller.service -f

# Monitor zrok Frontend
journalctl -u docker-zrok-frontend.service -f
```

### Checking Container Status
```bash
docker ps | grep -E "ziti|zrok"
```

### Troubleshooting Connectivity
If a public share is not reachable:
1. Verify the wildcard DNS record is correctly resolving.
2. Check if the `ziti-controller` is reachable on its advertised port (default `1280`).
3. Ensure the `zrok-frontend` identity is correctly enrolled in the controller.
