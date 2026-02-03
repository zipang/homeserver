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

### Administrative Commands (The `podman exec` logic)
Administrative commands (like creating accounts) must be run inside the `zrok-controller` container because it has direct access to the `ZROK_ADMIN_TOKEN` and the internal database.

We use `podman exec -it zrok-controller zrok ...` to run the `zrok` binary that is already installed inside the container.

## Operational Guides

### First-Time Setup
After the infrastructure is deployed and containers are running, follow these steps to initialize your user environment:

1.  **Create your User Account**:
    Run this command to create your first admin/user account:
    ```bash
    podman exec -it zrok-controller zrok admin create account <your_email> <a_password>
    ```
    *Note: This command will return an **Account Token**. This is your personal "debit card" to use zrok.*

2.  **Configure the Host CLI**:
    Point the local `zrok` CLI (installed on SKYLAB) to your self-hosted instance:
    ```bash
    zrok config set apiEndpoint http://localhost:18080
    ```

3.  **Enable the Environment**:
    Activate the SKYLAB server for your new account:
    ```bash
    zrok enable <your_account_token>
    ```
    *This creates a hidden `.zrok` folder in your home directory containing your environment identity.*

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

### Nginx Reverse Proxy Integration (Optional)
If you already have Nginx running on ports 80/443, you can configure it to proxy traffic to the `zrok-frontend` (running on ports 10081 and 10082).

Add these virtual hosts to your Nginx configuration:

```nix
# Wildcard for all zrok public shares
services.nginx.virtualHosts."*.skylab.quest" = {
  forceSSL = true;
  sslCertificate = "/var/lib/secrets/certs/skylab.crt";
  sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
  locations."/" = {
    proxyPass = "http://127.0.0.1:10081";
    proxyWebsockets = true;
    extraConfig = ''
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
    '';
  };
};

# OAuth handler
services.nginx.virtualHosts."oauth.skylab.quest" = {
  forceSSL = true;
  sslCertificate = "/var/lib/secrets/certs/skylab.crt";
  sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
  locations."/" = {
    proxyPass = "http://127.0.0.1:10082";
    proxyWebsockets = true;
  };
};
```

## Headless Operations & Troubleshooting

### Monitoring Logs
```bash
# Monitor OpenZiti Controller
journalctl -u podman-ziti-controller.service -f

# Monitor zrok Controller
journalctl -u podman-zrok-controller.service -f

# Monitor zrok Frontend
journalctl -u podman-zrok-frontend.service -f
```

### Checking Container Status
```bash
podman ps | grep -E "ziti|zrok"
```

### Recovery & State Reset
If the Ziti database becomes out of sync with your secrets (e.g., authentication failures for `admin`), you can perform a fresh start of the data stack without losing your generated secrets.

Run the recovery script:
```bash
sudo ./scripts/reset-zrok.sh
```

Then restart the services in order:
1. `sudo systemctl start zrok-init.service`
2. `sudo systemctl start podman-ziti-controller.service`
3. Wait 15s for initialization, then: `sudo systemctl start podman-zrok-controller.service`
4. `sudo systemctl start podman-zrok-frontend.service`

### Troubleshooting Connectivity
If a public share is not reachable:
1. Verify the wildcard DNS record is correctly resolving.
2. Check if the `ziti-controller` is reachable on its advertised port (default `1280`).
3. Ensure the `zrok-frontend` identity is correctly enrolled in the controller.
