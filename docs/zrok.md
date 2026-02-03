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
The `zrok.nix` module leverages the system's existing Nginx service to serve a home page on local port **8085**.

In NixOS, the home page content is managed **declaratively**:
- The source files are located in the `www/` directory of this repository.
- The `nginx.nix` module uses a relative path (`root = ../../www;`), which causes Nix to copy the files into the immutable **Nix Store** during deployment.
- This ensures the home page is always consistent with the Git repository, regardless of where the repo is cloned on the server.

## Operational Guides

### Initial Setup
Before sharing any service, you must initialize your environment:

1.  **Configure API Endpoint**:
    ```bash
    zrok config set apiEndpoint http://localhost:18080
    ```
2.  **Enable Environment**:
    Use the token generated during account creation (see `WORK_IN_PROGRESS.md`):
    ```bash
    zrok enable <account_token>
    ```

### Public Sharing (with OAuth)
Public sharing makes a service accessible via the internet on your domain (e.g., `skylab.quest`). In our self-hosted setup, these are automatically protected by Google OAuth.

#### Method 1: Reserved Share (Recommended for permanent services)
This ensures the subdomain remains the same across restarts.

1.  **Reserve the name**:
    ```bash
    zrok reserve public --name <service_name> --backend-mode proxy http://localhost:<port>
    ```
2.  **Start the share**:
    ```bash
    zrok share reserved <service_name>
    ```

#### Method 2: Ephemeral Share (For testing)
```bash
zrok share public http://localhost:<port> --backend-mode proxy
```
*Note: This will generate a random subdomain.*

### Private Sharing
Private sharing does **not** expose the service to the internet. Instead, it creates a peer-to-peer tunnel between your server and a specific client. This is ideal for highly sensitive services or internal tools.

1.  **Start the private share on the server**:
    ```bash
    zrok share private http://localhost:<port> --backend-mode proxy
    ```
    *Note: This command will output a **Share Token** (e.g., `v3rt1g0`).*

2.  **Access the share from a client**:
    On your laptop or another machine with `zrok` installed:
    ```bash
    zrok access private <share_token>
    ```
    This will start a local proxy (usually on `localhost:9191`) that tunnels directly to your server.

### Google OAuth Configuration
1. Set the **Authorized Redirect URI** to `https://oauth.skylab.quest/google/callback`.
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
