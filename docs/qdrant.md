# Qdrant Vector Database

Qdrant is the vector search engine used by the `hybrid-rag-retrieval` project
for dense, sparse and multivector retrieval. SKYLAB runs it as a single local
node, with the REST API bound to loopback and an HTTPS-only administration
dashboard exposed on the local network.

- **Module path**: `modules/services/qdrant.nix`
- **Pinned server version**: Qdrant `1.20.0`
- **Pinned dashboard version**: Qdrant Web UI `0.2.20`
- **Dashboard URL**: `https://qdrant.skylab.local/dashboard`
- **API (local only)**: `http://127.0.0.1:6333`
- **gRPC (local only)**: `http://127.0.0.1:6334`

> [!IMPORTANT]
> This setup has **no application-level authentication**: no Basic Auth, no
> API key and no OIDC. The Nginx allowlist and the loopback bind are the only
> access controls. SSH keys protect the shell, not HTTPS requests. See
> [Security](#security) before exposing the service further.

## Configuration Reference

The complete list of available options for the `services.qdrant` module can be
found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.qdrant)
for the current channel (25.11).

The pinned package derivations live next to the module:

- `packages/qdrant.nix`: official `qdrant-x86_64-unknown-linux-gnu` release
  binary, patched for NixOS with `autoPatchelfHook`;
- `packages/qdrant-web-ui.nix`: official `dist-qdrant.zip` dashboard bundle,
  served by Qdrant from `service.static_content_dir`.

## Full Configuration Template

### Server package

```nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qdrant";
  version = "1.20.0";

  src = fetchurl {
    url = "https://github.com/qdrant/qdrant/releases/download/v${finalAttrs.version}/qdrant-x86_64-unknown-linux-gnu.tar.gz";
    hash = "sha256-I2Hz3w3t/vMfVET58VvRXWtKbLpq2VLa7MX744Z8XuY=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # The release archive holds a single file at its root, with no directory:
  # tell unpackPhase to use the build directory as the source root.
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 qdrant $out/bin/qdrant
    runHook postInstall
  '';

  meta = {
    description = "Qdrant vector search engine, pinned to the version used by the RAG project";
    homepage = "https://github.com/qdrant/qdrant";
    license = lib.licenses.asl20;
    mainProgram = "qdrant";
    platforms = [ "x86_64-linux" ];
  };
})
```

### Dashboard package

```nix
{
  lib,
  stdenv,
  fetchurl,
  unzip,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "qdrant-web-ui";
  version = "0.2.20";

  src = fetchurl {
    url = "https://github.com/qdrant/qdrant-web-ui/releases/download/v${finalAttrs.version}/dist-qdrant.zip";
    hash = "sha256-Mx1vg+48DncaArgOxY3zhX5+urmbfL3RoVviBakhXT0=";
  };

  nativeBuildInputs = [ unzip ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/. $out/
    runHook postInstall
  '';

  meta = {
    description = "Qdrant Web UI, pinned to the version aligned with Qdrant 1.20.0";
    homepage = "https://github.com/qdrant/qdrant-web-ui";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
```

### NixOS module

```nix
{ config, pkgs, ... }:

let
  qdrant = pkgs.callPackage ../../packages/qdrant.nix { };
  qdrant-web-ui = pkgs.callPackage ../../packages/qdrant-web-ui.nix { };
in
{
  services.qdrant = {
    enable = true;
    package = qdrant;
    webUIPackage = qdrant-web-ui;

    settings = {
      service = {
        host = "127.0.0.1";
        http_port = 6333;
        grpc_port = 6334;
        enable_cors = false;
      };

      storage = {
        storage_path = "/var/lib/qdrant/storage";
        snapshots_path = "/var/lib/qdrant/snapshots";
      };

      telemetry_disabled = true;
    };
  };

  # HTTPS only, no HTTP listener for this host.
  services.nginx.virtualHosts."qdrant.${config.server.privateDomain}" = {
    onlySSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    extraConfig = ''
      allow 192.168.1.0/24;
      allow 127.0.0.1;
      allow ::1;
      deny all;
    '';

    locations."/" = {
      proxyPass = "http://127.0.0.1:6333";
    };
  };
}
```

The module is imported from `hosts/SKYLAB/configuration.nix`:

```nix
../../modules/services/qdrant.nix
```

## Operational Guides

### Access the dashboard

1. Make `qdrant.skylab.local` resolve to SKYLAB:
   - add it to your local DNS, or
   - add an entry to your client `hosts` file:

     ```text
     192.168.1.XX  qdrant.skylab.local
     ```

2. Import the SKYLAB local CA on the client once, as described in
   [Security & SSL Setup](./security.md#4-installing-the-skylab-root-ca-on-client-machines).

3. Open:

   ```text
   https://qdrant.skylab.local/dashboard
   ```

There is deliberately **no HTTP vhost** for this name (`onlySSL = true`).
Requests to `http://qdrant.skylab.local` are not served by the Qdrant vhost.

### SSH tunnel fallback

Qdrant still listens on loopback, so an SSH tunnel works without Nginx:

```bash
ssh -L 6333:127.0.0.1:6333 zipang@skylab
```

Then open `http://127.0.0.1:6333/dashboard` locally, or use the REST API at
`http://127.0.0.1:6333`.

### REST API examples

From SKYLAB itself:

```bash
# Version and health
curl -s http://127.0.0.1:6333/ | jq -r .version
curl -s http://127.0.0.1:6333/readyz

# Collections
curl -s http://127.0.0.1:6333/collections | jq

# Metrics
curl -s http://127.0.0.1:6333/metrics | head
```

From a LAN client through Nginx:

```bash
curl -sk https://qdrant.skylab.local/ | jq -r .version
curl -sk https://qdrant.skylab.local/collections | jq
```

The `-k` flag is only needed if the client does not trust the SKYLAB local CA
yet. Prefer installing the CA and omitting `-k`.

### Data location

The systemd unit uses `DynamicUser = true` and `StateDirectory = "qdrant"`.
The configured paths are therefore visible on the host as:

```text
/var/lib/private/qdrant/storage
/var/lib/private/qdrant/snapshots
```

The RAG project uses `QDRANT_URL=http://127.0.0.1:6333` because it runs on
SKYLAB itself.

### Backup

Offline copy, safe when the service is stopped:

```bash
sudo systemctl stop qdrant
sudo cp -a /var/lib/private/qdrant /backup/qdrant-$(date +%F)
sudo systemctl start qdrant
```

Online backup with a Qdrant snapshot:

```bash
# Replace "my_collection" with the actual collection name.
COLLECTION=my_collection

# Create a snapshot for one collection
curl -s -X POST "http://127.0.0.1:6333/collections/${COLLECTION}/snapshots" | jq

# List snapshots
curl -s "http://127.0.0.1:6333/collections/${COLLECTION}/snapshots" | jq
```

Snapshot files are written under `/var/lib/private/qdrant/snapshots` on the
host. Copy them to the backup location after creation.

### Upgrade procedure

1. Check the upstream release notes and confirm that the RAG project supports
   the new version.
2. Update `version` and `hash` in `packages/qdrant.nix`.
3. Update `version` and `hash` in `packages/qdrant-web-ui.nix` when a
   matching dashboard release exists.
4. Deploy:

   ```bash
   update-nix
   ```

5. Validate:

   ```bash
   curl -s http://127.0.0.1:6333/ | jq -r .version
   curl -sk https://qdrant.skylab.local/dashboard | head
   ```

6. Rerun the RAG project checks (multivector behaviour, a probe import and
   `bun test`). The project's measurements were originally taken on Qdrant
   1.19.1, so a version change needs a fresh validation pass.

To compute the SRI hash of a release asset:

```bash
curl -fsSL -o qdrant.tar.gz \
  https://github.com/qdrant/qdrant/releases/download/v1.20.0/qdrant-x86_64-unknown-linux-gnu.tar.gz

echo "sha256-$(openssl dgst -sha256 -binary qdrant.tar.gz | base64 -w0)"
```

## Security

| Control | Status |
| :--- | :--- |
| Qdrant bind address | `127.0.0.1` only |
| Nginx TLS | `onlySSL = true`, wildcard `*.skylab.local` certificate |
| HTTP listener for this vhost | None |
| Nginx allowlist | `192.168.1.0/24`, `127.0.0.1`, `::1` |
| CORS | Disabled (`service.enable_cors = false`) |
| Qdrant API key | Not configured |
| Basic Auth / SSO | Not configured |

Because Qdrant has no application authentication, **any client allowed by the
allowlist can create, modify or delete collections**. The allowlist is a
network boundary, not an identity check: SSH keys do not authenticate HTTPS
requests.

Adjust `extraConfig` if your access path changes:

- Netbird peers: add the mesh range, usually `100.64.0.0/10`;
- Docker bridge: add the Docker network range;
- SSH tunnel only: keep `127.0.0.1` and remove the LAN range.

If the service must be exposed beyond the LAN, add an API key and update the
RAG client to send the `api-key` header, or put an authenticating proxy in
front of it.

## Headless Operations & Troubleshooting

### Service status and logs

```bash
systemctl status qdrant
journalctl -u qdrant -f
journalctl -u qdrant -n 100 --no-pager
```

### Restart

```bash
sudo systemctl restart qdrant
```

### Verify listeners

```bash
ss -ltnp | grep -E '6333|6334'
```

Expected: both sockets bound to `127.0.0.1`, never `0.0.0.0`.

### Verify Nginx configuration

```bash
sudo nginx -t
journalctl -u nginx -f
```

### Common issues

| Symptom | Likely cause |
| :--- | :--- |
| `403 Forbidden` | Client IP is not in the Nginx allowlist |
| `502 Bad Gateway` | Qdrant is not running, or not listening on `127.0.0.1:6333` |
| `404` on `/dashboard` | Dashboard package missing, or `service.static_content_dir` wrong |
| TLS certificate error | Client does not trust the SKYLAB local CA, or the wildcard certificate expired |
| `version` is not `1.20.0` | The pinned package was not rebuilt or not deployed |
| Hash mismatch during build | Release asset changed, or the SRI hash is wrong |

### Check the installed version

```bash
curl -s http://127.0.0.1:6333/ | jq -r .version
# expected: 1.20.0
```

### Check disk usage

```bash
du -sh /var/lib/private/qdrant
```

Plan for several GB once the RAG collections are imported (dense, BM25,
multivector and HNSW data).
