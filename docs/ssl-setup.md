# SSL/TLS Certificate Setup (HTTPS)

To ensure secure connections within the local network and remove browser warnings, we use a **Local Certificate Authority (CA)**.

## The Challenge: SSL on `.local` Domains

Standard Certificate Authorities (like Let's Encrypt) require you to prove ownership of a domain via a public DNS record. Since `.local` domains are reserved for local networks and are not reachable from the internet, Let's Encrypt cannot issue certificates for them.

**Our Solution**: We use `mkcert` to act as our own private Certificate Authority.

## 1. Prerequisites

Ensure `mkcert` is installed on your local management machine (not just the server).
* **Linux**: `sudo dnf install mkcert` or `sudo apt install mkcert`
* **macOS**: `brew install mkcert`
* **NixOS**: `nix-shell -p mkcert`

## 2. Generate the Local Root CA

Run this once on your **local machine**:

```bash
mkcert -install
```

This creates a Root CA and installs it into your system's trust store (browsers, OS).

## 3. Generate Wildcard Certificates for SKYLAB

Generate a certificate that covers all `.skylab.local` subdomains:

```bash
# Create a temporary directory for certs
mkdir -p temp_certs && cd temp_certs

# Generate the certificate for the main host and wildcard subdomains
mkcert "*.skylab.local" skylab.local 127.0.0.1 ::1
```

You will get two files:
- `_wildcard.skylab.local+3.pem` (The Certificate)
- `_wildcard.skylab.local+3-key.pem` (The Private Key)

## 4. Deploying the Certificates

We use **Manual Deployment** to keep private keys entirely out of the Git repository history.

1.  **Generate the files** on your local machine as shown in step 3.
2.  **Copy the files** from your local machine to SKYLAB using `scp`:
    ```bash
    scp _wildcard.skylab.local+3.pem skylab:/var/lib/secrets/certs/skylab.crt
    scp _wildcard.skylab.local+3-key.pem skylab:/var/lib/secrets/certs/skylab.key
    ```
    *Note: The directory `/var/lib/secrets/certs` is automatically created with the correct permissions (`nginx:nginx`) by NixOS.*

## 5. NixOS Configuration

The services are configured to look for certificates in the persistent `/var/lib/secrets/certs` directory.

### Paths in Nix Modules
In `modules/services/nginx.nix` and `modules/services/immich.nix`:
```nix
sslCertificate = "/var/lib/secrets/certs/skylab.crt";
sslCertificateKey = "/var/lib/secrets/certs/skylab.key";
```

## 6. Trust the Root CA on other devices

For other devices (phones, other laptops) to trust SKYLAB:

1. Find the location of your `rootCA.pem`:
   ```bash
   mkcert -CAROOT
   ```
2. Copy the `rootCA.pem` file to your other device.
3. **Android/iOS**: Email it to yourself or use Syncthing, then open it and install it as a "Trusted Root Certificate" in the security settings.
4. **Browsers**: Some browsers (like Firefox) use their own trust store. You may need to manually import `rootCA.pem` into Firefox settings.

## Troubleshooting

### Browser still says "Not Secure"
- Verify you ran `mkcert -install` on the machine you are browsing from.
- Check if Nginx restarted correctly: `journalctl -u nginx.service -f`
- Clear browser cache or try an Incognito window.

### Certificate expired
- `mkcert` certificates usually last for 2+ years. To renew, simply repeat steps 3 and 4.
