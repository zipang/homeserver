# Netbird - Self-hosted Zero Trust Mesh VPN

Netbird is an open-source overlay network (mesh VPN) built on top of WireGuard. It allows you to connect your devices (laptops, phones, servers) into a single private network, regardless of their physical location or NAT restrictions.

In this homelab, we self-host the entire Netbird Control Plane and integrate it with **PocketID** for passwordless authentication via passkeys.

The server configuration is managed in `modules/services/netbird-server.nix`.
The client configuration is managed in `modules/services/netbird.nix`.

## Overview

**Purpose**: Provide secure, high-performance remote access to SKYLAB services (Immich, Jellyfin, etc.) without exposing them to the public internet.

**Key Features**:
- **Peer-to-Peer (P2P)**: Direct WireGuard connections between devices for maximum speed.
- **Zero Trust**: Integrated with PocketID (OIDC) for identity-based access.
- **NAT Traversal**: Automatic hole-punching or relay via STUN/TURN (Coturn).
- **Subnet Routing**: Access your entire home network through a single "Gateway" node.

**Architecture**:
- **Management Server**: Handles policies, peers, and OIDC logic.
- **Signal Server**: Helps peers find each other.
- **Relay (Coturn)**: Provides a fallback if P2P fails.
- **Dashboard**: Web interface for managing the network.

## Configuration Reference

- [Official Netbird Documentation](https://docs.netbird.io/)
- [Netbird Self-hosting Guide](https://docs.netbird.io/selfhosted/selfhosted-guide)
- [NixOS Netbird Options](https://search.nixos.org/options?channel=25.11&query=services.netbird) (Client only)

## OIDC Integration (PocketID)

To connect Netbird to PocketID, a new OIDC client must be created in the PocketID admin dashboard:

1. **Name**: `Netbird VPN`
2. **Redirect URI**: `https://netbird.yourdomain.com/auth/callback`
3. **Grant Types**: `Authorization Code`, `Refresh Token`
4. **Scopes**: `openid`, `profile`, `email`

The resulting **Client ID** and **Client Secret** are used in the Netbird Management server configuration.

## Operational Guides

### 1. Installing the Netbird Client

#### On Linux (NixOS)
The client is already enabled on SKYLAB via `modules/services/netbird.nix`. To join the network:
```bash
sudo netbird up --management-url https://netbird.yourdomain.com
```

#### On Mobile (iOS/Android)
1. Download the **Netbird** app from the App Store or Play Store.
2. Open Settings and set the **Management URL** to `https://netbird.yourdomain.com`.
3. Click **Connect**. It will redirect you to PocketID for authentication.
4. Scan your finger/face (Passkey) and you are connected.

#### On Windows/macOS
1. Download the installer from [netbird.io](https://netbird.io/download).
2. During setup or in Preferences, enter your self-hosted **Management URL**.
3. Authenticate via PocketID.

### 2. Accessing Services (Immich/Jellyfin)

Once connected to Netbird, your devices are on a private virtual network (usually `100.64.0.0/10`).

- **Via Private IP**: You can access SKYLAB using its Netbird IP (e.g., `http://100.64.0.1:2283` for Immich).
- **Via Private DNS**: If Netbird DNS is configured, you can use `http://skylab.netbird.cloud:2283`.
- **Via Local DNS (Magic)**: You can configure Netbird to resolve your local `.skylab.local` domains by routing DNS queries to SKYLAB's internal Nginx.

### 3. Streaming with Jellyfin

Netbird is ideal for Jellyfin because it establishes a direct P2P connection.
1. Connect your phone to Netbird.
2. Open the Jellyfin app.
3. Use the Netbird IP of SKYLAB as the server address: `http://100.64.x.y:8096`.
4. Enjoy full-bandwidth streaming without Cloudflare's restrictions.

## Headless Operations & Troubleshooting

### Monitoring Server Logs (Docker)
Since the server runs in Docker via NixOS OCI containers:
```bash
# View all Netbird server components
docker ps | grep netbird

# Follow logs for management
docker logs -f netbird-management
```

### Checking Peer Status (Client)
```bash
# See which peers are connected and if they are P2P or Relayed
netbird status -d

# Expected Output:
# Peer ID: ...
# Local IP: 100.64.x.y
# Connection: P2P (Direct)  <-- This is what you want for performance
```

### Resetting Client State
If the client gets stuck or cannot authenticate:
```bash
sudo netbird down
sudo rm -rf /etc/netbird/config.json
sudo netbird up --management-url https://netbird.yourdomain.com
```

## Security Considerations

- **Management API**: The management API should always be behind HTTPS (Nginx handles this).
- **PocketID**: Ensure PocketID is accessible over HTTPS, otherwise Netbird's OIDC handshake will fail.
- **Firewall**: SKYLAB needs to allow UDP traffic for WireGuard (default port `51820`) to facilitate P2P connections.

## Useful Links
- [Netbird GitHub](https://github.com/netbirdio/netbird)
- [WireGuard Performance Tips](https://www.wireguard.com/performance/)
