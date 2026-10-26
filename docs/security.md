# Server Security & SSL Setup

This document covers the TLS certificates and network security for SKYLAB:

1. **Public domain** — Let's Encrypt via Cloudflare DNS-01 (`modules/system/acme.nix`)
2. **Origin cloaking** — Nginx only accepts Cloudflare + LAN IPs (`modules/services/nginx.nix`, `modules/services/cloudflare-ips.nix`)
3. **Internal `.local` domain** — SKYLAB's own Root CA with automatic daily renewal (`modules/system/local-certs.nix`, `scripts/local-certs`)
4. **Client trust installation** — step-by-step instructions per OS/browser (safe to hand directly to an agent on any client machine)
5. **Maintenance & troubleshooting** — expiry checks, forced renewal, CA rotation, logs

---

## Network & Router Setup

| Service | Internal Port | External Port | Purpose |
| :--- | :--- | :--- | :--- |
| **HTTP** | 80 | 80 | Redirects to HTTPS |
| **HTTPS** | 443 | 443 | Public web traffic (proxied by Cloudflare) + internal `.local` virtual hosts |
| **SSH** | 22 | **2222** | Remote CLI access (non-standard external port cuts automated scan noise) |

Connect over the external SSH port with:

```bash
ssh -p 2222 user@yourdomain.com
```

---

## 1. Public Domain SSL (Let's Encrypt)

Configured in **`modules/system/acme.nix`**. Uses the **DNS-01 challenge** via Cloudflare so certificates can be issued and renewed without exposing port 80 for HTTP challenges.

### 1. Create a Cloudflare API Token

1. Point your domain's nameservers to Cloudflare.
2. Create a token at `My Profile > API Tokens > Create Token`:
   * Template: `Edit zone DNS`
   * Permissions: `Zone → DNS → Edit`
   * Zone Resources: `Include → Specific zone → yourdomain.com`

### 2. Provision the Secret on SKYLAB

```bash
sudo ./scripts/generate-acme-secrets
```

This writes the token to `/var/lib/secrets/acme/cloudflare_token` (outside Git).

### 3. Verify

```bash
systemctl status acme-yourdomain.com.service
journalctl -u acme-yourdomain.com.service -f
```

---

## 2. Cloudflare & Nginx Origin Cloaking

Configured in **`modules/services/nginx.nix`** and **`modules/services/cloudflare-ips.nix`**:

* **Real client IPs**: Nginx trusts Cloudflare's IP ranges and reads the visitor's real address from `CF-Connecting-IP`.
* **Access control**: Public virtual hosts only accept connections from Cloudflare IP ranges and the local LAN (`192.168.1.0/24`); direct hits to the public IP return `403 Forbidden`.

---

## 3. Internal SSL (`*.skylab.local`)

Public CAs cannot issue certificates for `.local` domains. SKYLAB runs its own local Certificate Authority on the server and renews the wildcard leaf certificate automatically.

Configured in **`modules/system/local-certs.nix`** and **`scripts/local-certs`**.

### Files on the Server

| Path | Content | Mode | Validity | Rotated? |
| :--- | :--- | :--- | :--- | :--- |
| `/var/lib/secrets/certs/skylab-ca.crt` | SKYLAB Root CA (public certificate) | `0444` | 10 years | Never automatically |
| `/var/lib/secrets/certs/skylab-ca.key` | SKYLAB Root CA private key | `0400` | — | Never leaves the server |
| `/var/lib/secrets/certs/skylab.crt` | Wildcard leaf (`*.skylab.local`, `skylab.local`, `127.0.0.1`, `::1`) | `0644` | 825 days | Auto-renewed when `< 30` days remain |
| `/var/lib/secrets/certs/skylab.key` | Wildcard leaf private key | `0600` | — | Re-generated on each renewal |
| `/etc/ssl/certs/skylab-local-ca.crt` | World-readable symlink to `skylab-ca.crt` (for `scp` to clients) | symlink | — | — |

### How Automatic Renewal Works

* **`skylab-local-certs.service`** (oneshot) runs before `nginx.service` on boot and during `nixos-rebuild switch`.
* **`skylab-local-certs.timer`** triggers the service **daily**.
* If `skylab.crt` is missing, not signed by `skylab-ca.crt`, or has fewer than **30 days** remaining, a new 825-day leaf is issued and `nginx` is reloaded automatically. Otherwise the script exits in milliseconds.

---

## 4. Installing the SKYLAB Root CA on Client Machines

> **Instructions for a human or an AI agent running on a client machine.**
> Goal: make the client OS and browsers trust `https://*.skylab.local` (e.g. `https://jellyfin.skylab.local`, `https://immich.skylab.local`).

### What to Copy (and What Never to Copy)

| File on SKYLAB | Copy to client? | Purpose |
| :--- | :--- | :--- |
| `/etc/ssl/certs/skylab-local-ca.crt` | **YES** (this is the only file you need) | Public Root CA trust anchor |
| `/var/lib/secrets/certs/skylab-ca.key` | **NEVER** | Root CA private key — must never leave SKYLAB |
| `/var/lib/secrets/certs/skylab.crt` / `.key` | **NO** | Server leaf cert/key — used only by Nginx on SKYLAB |

### Step 1 — Fetch and Verify the Root CA

Run on the client machine:

```bash
scp zipang@skylab:/etc/ssl/certs/skylab-local-ca.crt /tmp/skylab-local-ca.crt
openssl x509 -noout -subject -issuer -dates -fingerprint -sha256 -in /tmp/skylab-local-ca.crt
```

Expected output: `subject=O=SKYLAB, CN=SKYLAB Local CA` and a `notAfter` date ~10 years out.

---

### Step 2 — Install into the OS Trust Store

Pick the section matching the client OS:

#### Arch Linux / CachyOS / Manjaro / Fedora / RHEL (p11-kit)

```bash
sudo cp /tmp/skylab-local-ca.crt /etc/ca-certificates/trust-source/anchors/skylab-local-ca.crt
sudo chmod 0644 /etc/ca-certificates/trust-source/anchors/skylab-local-ca.crt
sudo trust extract-compat
trust list --filter=ca-anchors | grep -A3 "SKYLAB Local CA"
```

#### Debian / Ubuntu / Linux Mint / Pop!_OS (`update-ca-certificates`)

```bash
sudo cp /tmp/skylab-local-ca.crt /usr/local/share/ca-certificates/skylab-local-ca.crt
sudo chmod 0644 /usr/local/share/ca-certificates/skylab-local-ca.crt
sudo update-ca-certificates
awk -v cmd='openssl x509 -noout -subject' '/BEGIN/{close(cmd)};{print | cmd}' \
  < /etc/ssl/certs/ca-certificates.crt | grep "SKYLAB Local CA"
```

#### NixOS Client (declarative)

Add the file to the client's NixOS configuration and rebuild:

```nix
security.pki.certificateFiles = [ ./skylab-local-ca.crt ];
```

#### macOS

```bash
sudo security add-trusted-cert -d -r trustRoot \
  -k /Library/Keychains/System.keychain /tmp/skylab-local-ca.crt
security find-certificate -c "SKYLAB Local CA" /Library/Keychains/System.keychain
```

#### Windows (PowerShell as Administrator)

```powershell
Import-Certificate -FilePath C:\path\to\skylab-local-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

#### iOS / iPadOS

1. Send `skylab-local-ca.crt` to the device via AirDrop, files share, or email and tap it.
2. Open **Settings → Profile Downloaded → Install**.
3. Open **Settings → General → About → Certificate Trust Settings** and enable full trust for **SKYLAB Local CA**.

#### Android

1. Copy `skylab-local-ca.crt` onto the device.
2. Open **Settings → Security → Encryption & credentials → Install a certificate → CA certificate** and select `skylab-local-ca.crt`.

---

### Step 3 — Browsers on Linux (Use Their Own Cert Store)

On Linux, Chromium-based browsers and Firefox do **not** read `/etc/ssl/certs` by default. Configure them explicitly:

#### Chrome / Chromium / Brave / Edge / Vivaldi (NSS database in `~/.pki/nssdb`)

```bash
# Install certutil if missing:
#   Arch/CachyOS: sudo pacman -S --needed nss
#   Debian/Ubuntu: sudo apt install -y libnss3-tools
mkdir -p "$HOME/.pki/nssdb"
[ -f "$HOME/.pki/nssdb/cert9.db" ] || certutil -d "sql:$HOME/.pki/nssdb" -N --empty-password
certutil -d "sql:$HOME/.pki/nssdb" -D -n "SKYLAB Local CA" 2>/dev/null || true
certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n "SKYLAB Local CA" -i /tmp/skylab-local-ca.crt
certutil -d "sql:$HOME/.pki/nssdb" -L
```

Then fully restart the browser (`chrome://restart`).

#### Firefox / Zen / Floorp

Option A — tell Firefox to trust the OS store via a policy file (works for all profiles, survives updates):

```bash
# Locate the Firefox installation directory (e.g. /usr/lib/firefox or /etc/firefox/policies)
sudo mkdir -p /etc/firefox/policies
sudo tee /etc/firefox/policies/policies.json >/dev/null <<'EOF'
{
  "policies": {
    "Certificates": {
      "ImportEnterpriseRoots": true,
      "Install": ["/etc/ca-certificates/trust-source/anchors/skylab-local-ca.crt"]
    }
  }
}
EOF
```

(On Debian/Ubuntu, replace the path in `"Install"` with `"/usr/local/share/ca-certificates/skylab-local-ca.crt"`.)

Option B — manual import in the UI:
*Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import…* → select `skylab-local-ca.crt` → check **Trust this CA to identify websites**.

---

### Step 4 — Remove Any Obsolete `mkcert` Root CA (Optional Cleanup)

If the client previously trusted an old `mkcert` CA for `skylab.local`, remove it once Step 5 passes:

```bash
# Arch / Fedora (p11-kit):
trust list --filter=ca-anchors | grep -B2 -i mkcert
sudo rm -f /etc/ca-certificates/trust-source/anchors/mkcert*.crt
sudo trust extract-compat

# Debian / Ubuntu:
sudo rm -f /usr/local/share/ca-certificates/mkcert*.crt
sudo update-ca-certificates --fresh

# Chrome / Chromium NSS DB:
certutil -d "sql:$HOME/.pki/nssdb" -L | grep -i mkcert
# then: certutil -d "sql:$HOME/.pki/nssdb" -D -n "<exact nickname>"
```

---

### Step 5 — Verify from the Client

```bash
# 1. Verify against the downloaded CA file directly
curl --cacert /tmp/skylab-local-ca.crt -sSI https://jellyfin.skylab.local | head -n 5

# 2. Verify using the OS trust store (no --cacert, no -k)
curl -sSI https://jellyfin.skylab.local | head -n 5

# 3. Inspect the live certificate served by Nginx
openssl s_client -connect jellyfin.skylab.local:443 -servername jellyfin.skylab.local </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates
```

Expected:
* `issuer=O=SKYLAB, CN=SKYLAB Local CA`
* `subject=O=SKYLAB, CN=*.skylab.local`
* `curl` exits with `0` and prints an HTTP status line (`HTTP/2 200` or `302`).

Clean up the temporary copy when finished:

```bash
rm -f /tmp/skylab-local-ca.crt
```

---

## 5. Server Maintenance & Troubleshooting (on SKYLAB)

### Check Certificate Expiration

```bash
# Root CA and wildcard leaf expiration dates
openssl x509 -enddate -noout -in /var/lib/secrets/certs/skylab-ca.crt
openssl x509 -enddate -noout -in /var/lib/secrets/certs/skylab.crt

# Returns exit code 0 if valid for at least 30 more days, 1 if renewal is due
openssl x509 -checkend 2592000 -noout -in /var/lib/secrets/certs/skylab.crt
```

### Check the Service and Daily Timer

```bash
systemctl status skylab-local-certs.service
systemctl list-timers skylab-local-certs.timer
journalctl -u skylab-local-certs.service -n 50
```

### Force an Immediate Renewal of the Leaf Certificate

Keeps the existing Root CA (clients do **not** need to re-import anything):

```bash
cd /home/zipang/homeserver
sudo MIN_VALID_DAYS=9999 ./scripts/local-certs skylab.local
```

(`scripts/local-certs` reloads `nginx` automatically when it re-issues the certificate.)

### Rotate the Root CA (Emergency Only)

Rotating the Root CA invalidates trust on **every** client device until they re-run Section 4:

```bash
sudo rm -f /var/lib/secrets/certs/skylab-ca.key \
           /var/lib/secrets/certs/skylab-ca.crt \
           /var/lib/secrets/certs/skylab-ca.srl
sudo systemctl start skylab-local-certs.service
```

Then repeat [Section 4](#4-installing-the-skylab-root-ca-on-client-machines) on each client device.

### Reload Nginx Manually

```bash
sudo systemctl reload nginx
```
