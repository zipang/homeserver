# zrok (Self-Hosted)

## Overview
`zrok` is an open-source sharing platform built on [OpenZiti](https://openziti.io/). It allows you to securely share local services (like Nextcloud or Immich) with the public internet using encrypted tunnels and integrated OAuth (Google/GitHub) authentication.

In SKYLAB, `zrok` replaces both Cloudflare Tunnels and Authelia for public access and SSO.

- **NixOS Module**: `modules/services/zrok.nix`
- **Official Docs**: [zrok.io](https://docs.zrok.io/)

## Initial Setup

Before starting any zrok services, you must run the setup script to generate all required secrets and configuration files:

```bash
# Generate all secrets and configuration files
sudo /home/master/homeserver/scripts/generate-zrok-setup.sh
```

This script will:
1. Create all required directories with correct ownership
2. Generate secure random secrets (admin tokens, passwords)
3. Create environment files (controller.env, frontend.env)
4. Create configuration files (config.yml for controller and frontend)
5. Set proper permissions and ownership for all files
6. Display a summary of created files

**Important**: After running the setup script, edit `/var/lib/secrets/zrok/frontend.env` to add your Google OAuth credentials:
- `ZROK_OAUTH_GOOGLE_CLIENT_ID`
- `ZROK_OAUTH_GOOGLE_CLIENT_SECRET`

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

### Secrets Management
`zrok` environment files are managed manually inside `/var/lib/secrets/zrok/` to keep them outside of the Git repository.

The setup script creates and manages these files:
- **`controller.env`**: Contains `ZROK_ADMIN_TOKEN` and `ZITI_PWD`.
- **`frontend.env`**: Contains Google OAuth credentials and the `ZROK_OAUTH_HASH_KEY`.

See the Initial Setup section above for running the setup script.

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

The zrok containers are managed by systemd services and should be controlled via `systemctl` commands, not manual Podman commands.

### Service Management
```bash
# Start/Stop/Restart services
systemctl start podman-ziti-controller.service
systemctl stop podman-ziti-controller.service
systemctl restart podman-ziti-controller.service

# Check service status
systemctl status podman-ziti-controller.service
systemctl status podman-zrok-controller.service
systemctl status podman-zrok-frontend.service

# Enable/disable services on boot
systemctl enable podman-ziti-controller.service
systemctl disable podman-ziti-controller.service
```

### Monitoring Logs
```bash
# Monitor OpenZiti Controller
journalctl -u podman-ziti-controller.service -f

# Monitor zrok Controller
journalctl -u podman-zrok-controller.service -f

# Monitor zrok Frontend
journalctl -u podman-zrok-frontend.service -f
```

## Docker/Podman Configuration Reference

### Official zrok Docker Images Configuration

The official zrok Docker setup uses a specific architecture with OCI containers. Understanding this helps when deploying with Podman.

#### Container Architecture

Based on the official [zrok Docker Compose](https://github.com/openziti/zrok/blob/main/docker/compose/zrok-instance/compose.yml), the setup consists of:

1. **ziti-quickstart**: OpenZiti controller + router in quickstart mode
   - Image: `docker.io/openziti/ziti-cli:latest`
   - UID: `${ZIGGY_UID:-1000}` or `${ZIGGY_UID:-2171}`
   - Command: `ziti edge quickstart --home /home/ziggy/quickstart`
   - Ports: `${ZITI_CTRL_ADVERTISED_PORT:-80}`, `${ZITI_ROUTER_PORT:-3022}`
   - Healthcheck: `ziti agent stats` every 3s

2. **ziti-quickstart-init**: Permission fix for volumes
   - Image: `busybox`
   - Command: `chown -Rc ${ZIGGY_UID:-1000} /home/ziggy`

3. **zrok-permissions**: Permission fix for zrok volumes
   - Image: `busybox`
   - Command: `chown -Rc ${ZIGGY_UID:-2171} /var/lib/zrok-*`

4. **zrok-controller**: zrok controller service
   - Build: Uses `zrok-controller.Dockerfile` with envsubst
   - UID: `${ZIGGY_UID:-2171}`
   - Command: `zrok controller /etc/zrok-controller/config.yml --verbose`
   - Config: Generated from `zrok-controller-config.yml.envsubst` template
   - Environment variables: `ZROK_ADMIN_TOKEN`, `ZITI_PWD`, `ZROK_CTRL_PORT`, etc.

5. **zrok-frontend**: zrok frontend public access
   - Build: Uses `zrok-frontend.Dockerfile` with envsubst
   - UID: `${ZIGGY_UID:-2171}`
   - Command: `zrok access public /etc/zrok-frontend/config.yml --verbose`
   - Config: Generated from `zrok-frontend-config.yml.envsubst` template

#### Official Configuration Template (zrok-controller)

```yaml
v: 4
admin:
  secrets:
    - ${ZROK_ADMIN_TOKEN}
endpoint:
  host: 0.0.0.0
  port: ${ZROK_CTRL_PORT}
invites:
  invites_open: true
  token_strategy: store
store:
  path: /var/lib/zrok-controller/sqlite3.db
  type: sqlite3
ziti:
  api_endpoint: https://ziti.${ZROK_DNS_ZONE}:${ZITI_CTRL_ADVERTISED_PORT}/edge/management/v1
  username: admin
  password: ${ZITI_PWD}
```

### Podman Adaptation Notes

When using Podman instead of Docker, consider these key differences:

1. **No Build-time Config Generation**: Podman doesn't support Docker Compose build-time envsubst, so we use `zrok-init` systemd service to generate configs at runtime.

2. **User Namespace Mapping**: Podman's `--userns` behavior differs from Docker. Ensure UID/GID consistency across containers and host directories.

3. **Network Aliases**: Podman supports network aliases but syntax differs. Use the same network name across all containers.

4. **Health Checks**: Podman's health check monitoring differs from Docker. Monitor logs and service status manually.

5. **Volume Permissions**: Podman maintains strict permissions. Use tmpfiles rules and systemd services to set correct ownership before container start.

### Container UID Reference

- **zrok UID**: 2171 (used by official zrok images)
- **ziti UID**: 2171 (shared by OpenZiti images)
- **Volume ownership**: All volumes (`/var/lib/ziti`, `/var/lib/zrok-*`, `/var/lib/secrets/zrok`) must be owned by UID 2171 for containers to read/write

### Environment Variables Reference

#### Required Variables (zrok-init expects these):

- `ZROK_ADMIN_TOKEN`: Admin token for zrok controller (32-char random string)
- `ZITI_PWD`: Password for Ziti admin user (24-char random string)
- `ZROK_CTRL_PORT`: Controller API port (default: 18080)
- `ZITI_CTRL_ADVERTISED_PORT`: Ziti controller port (default: 1280)
- `ZROK_DNS_ZONE`: DNS zone for wildcard records (e.g., `skylab.quest`)

#### Optional Variables (for zrok-frontend):

- `ZROK_OAUTH_HASH_KEY`: 32-char string for OAuth cookie signing/encryption
- `ZROK_OAUTH_GOOGLE_CLIENT_ID`: Google OAuth client ID
- `ZROK_OAUTH_GOOGLE_CLIENT_SECRET`: Google OAuth client secret

### Manual Container Testing (Podman - Debugging Only)

> **Important**: Use these commands only for debugging purposes. For normal operations, manage containers via systemd services as shown above in the Service Management section.

For troubleshooting and debugging, you can temporarily run containers manually with these Podman commands (this bypasses systemd service management):

```bash
# Create network (if not exists)
podman network create zrok-net

# Run ziti-controller manually
podman run --name ziti-controller-debug \
  --network=zrok-net \
  --env-file /var/lib/secrets/zrok/controller.env \
  -v /var/lib/ziti:/persistent \
  -p 1280:1280 -p 10080:10080 -p 3022:3022 \
  openziti/ziti-cli:latest edge quickstart controller --home /persistent

# Run zrok-controller manually
podman run --name zrok-controller-debug \
  --network=zrok-net \
  --env-file /var/lib/secrets/zrok/controller.env \
  -v /var/lib/zrok-controller:/var/lib/zrok-controller \
  -v /var/lib/ziti:/persistent \
  openziti/zrok:latest controller /var/lib/zrok-controller/config.yml

# Run zrok-frontend manually
podman run --name zrok-frontend-debug \
  --network=zrok-net \
  --env-file /var/lib/secrets/zrok/frontend.env \
  -v /var/lib/zrok-frontend:/var/lib/zrok-frontend \
  -p 10081:8080 -p 10082:8081 \
  openziti/zrok:latest access public /var/lib/zrok-frontend/config.yml
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

The script will automatically wipe the state and trigger the **automated bootstrap** process. You can monitor the progress by watching the bootstrap logs:
```bash
journalctl -u zrok-bootstrap.service -f
```

### Troubleshooting Connectivity
If a public share is not reachable:
1. Verify the wildcard DNS record is correctly resolving.
2. Check if the `ziti-controller` is reachable on its advertised port (default `1280`).
3. Ensure the `zrok-frontend` identity is correctly enrolled in the controller.
