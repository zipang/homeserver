# llama.cpp with llama-swap (llama-cpp)

## Overview

[`llama.cpp`](https://github.com/ggml-org/llama.cpp) is a lightweight C/C++
inference engine for GGUF models. On SKYLAB it is served through
[`llama-swap`](https://github.com/mostlygeek/llama-swap), a small reverse proxy
that **starts and stops `llama-server` on demand**, based on the `model` field
of each request.

```
client ──https──> nginx ──> llama-swap 127.0.0.1:9931
                               │  (model = "qwen3.5-2b")
                               └─> llama-server 127.0.0.1:10001+  (Vulkan/AMD)
```

- **llama-swap** listens on `127.0.0.1:9931`; Nginx exposes it at
  `https://llama.<privateDomain>` (Web UI, OpenAI API).
- Each model is a `llama-server` child on an automatically assigned loopback
  port (`${PORT}`, starting at 10001). Only one model is loaded at a time
  (4 GiB of VRAM on the Vega M GH); `globalTTL` unloads it after 15 min idle.
- Models are GGUF files in `/share/Skylab/LLMS` (MEDIAS subvolume, shared over
  NFS). The default is **Qwen3.5-2B**, vision-capable.

Configured in **`modules/services/llama-cpp.nix`**. The NixOS *module* is from
`nixos-25.11`; the *packages* (`llama-cpp-vulkan`, `llama-swap`) come from
`nixpkgs-unstable` because Qwen3.5 needs the `qwen35` architecture, which the
25.11 build (b6981) predates.

### Default model at a glance (verified from Hugging Face)

| Property | Value |
| --- | --- |
| Upstream repo | [`Qwen/Qwen3.5-2B`](https://huggingface.co/Qwen/Qwen3.5-2B) (released 2026-02-28) |
| GGUF repo | [`unsloth/Qwen3.5-2B-GGUF`](https://huggingface.co/unsloth/Qwen3.5-2B-GGUF) |
| Task | `image-text-to-text` — **vision + video + text** |
| Parameters | 2.27B (`Qwen3_5ForConditionalGeneration`, arch `qwen35`) |
| Context | 262,144 tokens native |
| License | Apache-2.0 |
| BF16 weights | ~4.56 GB (does **not** fit 4 GiB VRAM) |
| Q4_K_M weights | **1.28 GB** (used here) |
| Vision projector | `mmproj-F16.gguf` **0.67 GB** |
| Modalities | images (incl. OCR/documents), video, 201 languages |
| Thinking mode | supported; 2B runs in non-thinking mode by default |

Because the vision tower is a separate `mmproj` in llama.cpp (even though the
upstream model is unified), the model command loads **both** files.

Related pages: [Jellyfin](./jellyfin.md), [Monitoring](./monitoring.md).

### Why Vulkan and not ROCm?

The RX Vega M GH is a Vega 12 part (`gfx904`), which is **not** in ROCm's
supported GPU list. `llama-cpp-rocm` can sometimes be coerced with
`HSA_OVERRIDE_GFX_VERSION=9.0.0`, but it is unsupported and breaks between ROCm
releases. The Mesa RADV Vulkan backend is officially supported, ships in
`nixpkgs` as `llama-cpp-vulkan`, and generally matches or beats ROCm on this
generation of hardware.

`hardware.graphics.enable` is required: it installs the RADV driver and the
Vulkan ICD JSON files under `/run/opengl-driver`, which the (unwrapped)
`llama-server` binary discovers at runtime.

## Configuration Reference

* llama-swap upstream: <https://github.com/mostlygeek/llama-swap> · [`config.example.yaml`](https://github.com/mostlygeek/llama-swap/blob/main/docs/config.example.yaml)
* Package: [`llama-swap` (unstable)](https://search.nixos.org/packages?channel=unstable&query=llama-swap) · [`llama-cpp-vulkan` (unstable)](https://search.nixos.org/packages?channel=unstable&query=llama-cpp-vulkan)
* Default model: [`unsloth/Qwen3.5-2B-GGUF`](https://huggingface.co/unsloth/Qwen3.5-2B-GGUF)
* Vision: [llama.cpp multimodal docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
* Graphics stack: [`hardware.graphics.enable`](https://search.nixos.org/options?channel=25.11&query=hardware.graphics.enable)
* HF CLI: [`python3Packages.huggingface-hub`](https://search.nixos.org/packages?channel=25.11&query=huggingface-hub)

## Full Configuration Template

```nix
# modules/services/llama-cpp.nix
{ config, pkgs, pkgs-unstable, lib, ... }:

let
  modelsDir = "/share/Skylab/LLMS";
  llamaServer = "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server";
  configPath = "/var/lib/llama-swap/config.yaml";

  # Only used to seed a fresh install; the live config is mutable.
  seedModels = {
    "qwen3.5-2b" = {
      name = "Qwen3.5-2B (vision)";
      file = "Qwen3.5-2B-Q4_K_M.gguf";
      mmproj = "mmproj-F16.gguf";
      ctx = 8192;
    };
  };

  configSeed = pkgs.writeText "llama-swap-config.yaml" (lib.generators.toYAML { } {
    healthCheckTimeout = 300;
    logLevel = "info";
    sendLoadingState = true;
    startPort = 10001;
    globalTTL = 900;
    models = lib.mapAttrs (id: m: {
      inherit (m) name;
      cmd = ''
        ${llamaServer}
        --host 127.0.0.1 --port ''${PORT}
        -m ${modelsDir}/${m.file}
        --ctx-size ${toString m.ctx}
        --n-gpu-layers 999
        --jinja
      '' + lib.optionalString ((m.mmproj or null) != null)
             "--mmproj ${modelsDir}/${m.mmproj}\n";
    }) seedModels;
  });
in
{
  systemd.services.llama-swap = {
    description = "llama-swap - on-demand model switching for llama.cpp";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = [ modelsDir ];

    serviceConfig = {
      Type = "simple";
      User = "llama-swap";
      Group = "llama-swap";
      SupplementaryGroups = [ "video" "render" "users" ];
      StateDirectory = "llama-swap";
      StateDirectoryMode = "2775";
      ExecStart = "${pkgs-unstable.llama-swap}/bin/llama-swap --config ${configPath} --listen 127.0.0.1:9931 --watch-config";
      Restart = "on-failure";
      RestartSec = 10;

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = false; # llama-server children need /dev/dri
      ProtectHome = true;
      ProtectSystem = "strict";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      LockPersonality = true;
    };
  };

  # Seed once; `C` never overwrites an existing config.
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-swap 2775 llama-swap users -"
    "C ${configPath} 0664 root users - ${configSeed}"
    "d ${modelsDir}/.cache/huggingface 2775 zipang users -"
  ];

  users.groups.llama-swap = { };
  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
    extraGroups = [ "video" "render" "users" ];
    home = "/var/lib/llama-swap";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
    extraPackages = [ pkgs.vulkan-loader ];
  };

  services.nginx.virtualHosts."llama.${config.server.privateDomain}" = {
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
      proxyPass = "http://127.0.0.1:9931";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  environment.systemPackages = [
    pkgs-unstable.llama-cpp-vulkan
    pkgs-unstable.llama-swap
    pkgs.vulkan-loader
    pkgs.vulkan-tools
    pkgs.python3Packages.huggingface-hub
  ];
}
```

## Operational Guides

### Where models live

Models are plain `.gguf` files stored in the shared library
**`/share/Skylab/LLMS/`**: a dedicated Btrfs subvolume (`@llms`) on the
**MEDIAS** drive, mounted by `modules/system/storage.nix`:

```nix
fileSystems."/share/Skylab/LLMS" = {
  device = "/dev/disk/by-label/MEDIAS";
  fsType = "btrfs";
  options = [ "subvol=@llms" "compress=zstd" "noatime" ];
};
```

Because `/share/Skylab` is exported over NFS with `crossmnt`, the subvolume is
automatically published to the LAN as `/share/Skylab/LLMS`. The directory is
`2775 zipang:users` (setgid) and `llama-swap` is a member of `users`.

#### One-time creation on SKYLAB

The subvolume is not created by Nix:

```bash
sudo mkdir -p /mnt/medias
sudo mount -o subvolid=5 /dev/disk/by-label/MEDIAS /mnt/medias
sudo btrfs subvolume create /mnt/medias/@llms
sudo umount /mnt/medias
sudo nixos-rebuild switch --flake path:.#SKYLAB
init-llms
```

### Downloading models

#### The default model (`init-llms`)

`init-llms` is the one-shot bootstrap: it creates the directory and downloads
the default Qwen3.5-2B weights plus its vision projector. It is idempotent.

```bash
init-llms
init-llms --force   # re-download
```

#### Any other model (`llama-download`)

```bash
llama-download <repo> <file> [<file>...] [--mmproj <file>] [--revision <rev>] [--force]
```

Example:

```bash
llama-download bartowski/Qwen2.5-7B-Instruct-GGUF \
  Qwen2.5-7B-Instruct-Q4_K_M.gguf
```

It downloads into `LLAMA_MODELS_DIR` (default `/share/Skylab/LLMS`), fixes
ownership/permissions, then **prints a ready-to-paste `llama-swap` snippet**.
Run it as `zipang`; it re-raises a clear error if the directory is not
writable.

`llama-models` lists the local GGUF files (and the projectors) with sizes.

Both scripts download through a hidden `.staging/` directory: `hf --local-dir`
creates metadata in `<local-dir>/.cache/huggingface` and a temp file in the
parent of the destination, which fails when the destination is directly under
the root-owned `/share/Skylab`.

### llama-swap configuration

The live configuration is **`/var/lib/llama-swap/config.yaml`**, seeded from
Nix on first boot and **never overwritten afterwards** (`tmpfiles` rule `C`).
`llama-swap` runs with `--watch-config`: editing the file applies immediately.

A model entry looks like this (this is what `llama-download` prints):

```yaml
models:
  "qwen2.5-7b":
    name: "Qwen2.5 7B"
    cmd: |
      /run/current-system/sw/bin/llama-server
      --host 127.0.0.1 --port ${PORT}
      -m /share/Skylab/LLMS/Qwen2.5-7B-Instruct-Q4_K_M.gguf
      --ctx-size 8192 --n-gpu-layers 999 --jinja
```

- the key (`qwen2.5-7b`) is the **model ID** used by API clients;
- `${PORT}` is assigned by llama-swap (10001, 10002, …), so children never
  collide;
- add `--mmproj <file>` for vision models;
- optional keys: `ttl` (per-model idle unload), `aliases`, `concurrencyLimit`,
  `env`, `capabilities`, `useModelName`.

Global keys in use: `startPort: 10001`, `globalTTL: 900`,
`healthCheckTimeout: 300`, `sendLoadingState: true`.

Reset the config to the Nix seed:

```bash
sudo rm /var/lib/llama-swap/config.yaml
sudo systemd-tmpfiles --create
sudo systemctl restart llama-swap.service
```

### Start / stop / restart

`llama-swap` is a normal systemd service; it manages its `llama-server`
children itself (they are **not** separate units).

```bash
sudo systemctl start llama-swap.service
sudo systemctl stop llama-swap.service
sudo systemctl restart llama-swap.service
sudo systemctl status llama-swap.service
journalctl -u llama-swap.service -f
```

Do not use `systemctl edit`: the unit comes from the Nix module.

### Web UI and OpenAI-compatible endpoints

With `server.privateDomain = "skylab.local"`, everything is available on the
LAN at `https://llama.skylab.local`:

| URL | Purpose |
| --- | --- |
| `/ui` | llama-swap dashboard: models, load/unload, logs, playground |
| `/v1/models` | list configured models |
| `/v1/chat/completions` | OpenAI chat API (`model` = YAML key) |
| `/v1/completions`, `/v1/embeddings` | other OpenAI endpoints |
| `/running` | currently loaded model(s) |
| `POST /api/models/unload[/<id>]` | unload manually |
| `/logs/stream` | live logs |
| `/health` | liveness |

There is no API key: the LAN allowlist on the Nginx vhost is the boundary.

```bash
export OPENAI_BASE_URL=https://llama.skylab.local/v1
export OPENAI_API_KEY=local

curl -s "https://llama.skylab.local/v1/models" \
  --cacert /var/lib/secrets/certs/skylab-ca.crt | jq
```

#### Chat completion

```bash
curl -s http://127.0.0.1:9931/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.5-2b",
    "messages": [{ "role": "user", "content": "Hello" }],
    "max_tokens": 64
  }' | jq -r '.choices[0].message.content'
```

The first request to a cold model blocks while it loads
(`healthCheckTimeout: 300`), then subsequent requests are fast.

#### Vision (image input)

Qwen3.5-2B accepts images because its command includes `--mmproj`; llama-swap
auto-discovers the `image` capability. Send an OpenAI-style content array:

```bash
IMG=$(base64 -w0 photo.jpg)
curl -s http://127.0.0.1:9931/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"qwen3.5-2b\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": [
        {\"type\": \"text\", \"text\": \"Describe this image in one sentence.\"},
        {\"type\": \"image_url\", \"image_url\": {\"url\": \"data:image/jpeg;base64,$IMG\"}}
      ]
    }],
    \"max_tokens\": 256
  }" | jq -r '.choices[0].message.content'
```

Each image consumes context tokens; keep `--ctx-size 8192` for one image, or
reduce the image count/resolution if responses are truncated.

### Selecting a model

Clients simply use the YAML key as `model`. To see what is configured:

```bash
curl -s http://127.0.0.1:9931/v1/models | jq -r '.data[].id'
```

To preload a model at startup, add to the config:

```yaml
hooks:
  on_startup:
    preload:
      - "qwen3.5-2b"
```

### SSD or HDD for the model directory?

Inference is compute-bound, so storage speed only matters for cold starts and
model swaps. llama.cpp `mmap`s the GGUF; after the first load it lives in the
page cache (16 GiB RAM covers one 2–8 GB model). A HDD is fine for a library of
models; an SSD helps when you swap often. Do not put the service's models on
NFS/SMB.

### Per-user cache (`~/.cache/huggingface/`)

`hf` defaults to `~/.cache/huggingface/hub` when you omit `--local-dir`. That
cache is personal and not what llama-swap reads. Always download through the
scripts (or pass `--local-dir /share/Skylab/LLMS`).

### GPU access for your own user

`llama-swap` and its children run as the static `llama-swap` user, a member of
`video`, `render`, and `users`. Regular accounts are not. To run `llama-cli`
with GPU offload as `zipang`, add yourself to those groups and re-login:

```nix
users.users.zipang.extraGroups = [ "wheel" "docker" "networkmanager" "video" "render" ];
```

## Headless Operations & Troubleshooting

### Logs and status

```bash
journalctl -u llama-swap.service -f          # proxy + upstream logs
journalctl -u llama-swap.service -b --no-pager | tail -100
curl -s http://127.0.0.1:9931/running
```

### Ports and process checks

```bash
ss -ltnp | grep -E '9931|100[0-9][0-9]'
systemctl show -p ExecStart,User,Group,StateDirectory llama-swap.service
```

### Model fails to load / 500 or 502 on first request

`llama-swap` reports the child's stderr in `journalctl -u llama-swap`. Usual
causes:

- the `.gguf` path in the config is wrong or not readable;
- `unknown model architecture: qwen35` → the child is the 25.11 `llama-server`,
  not the unstable one. Check
  `systemctl cat llama-swap.service | grep llama-server` and the `cmd` path.
- VRAM too small: lower `--n-gpu-layers`, `--ctx-size`, or pick a smaller
  quantization.

```bash
sudo -u llama-swap test -r /share/Skylab/LLMS/<file>.gguf && echo OK
ls -ld /share/Skylab/LLMS          # expect drwxrwsr-x zipang users
findmnt /share/Skylab/LLMS
```

### Config edits are ignored

`--watch-config` reloads on save, but a YAML syntax error is logged and the
previous config is kept:

```bash
journalctl -u llama-swap.service -n 30 | grep -i config
```

Validate the file with any YAML parser (the seed config is valid by
construction), then restart if needed:

```bash
sudo systemctl restart llama-swap.service
```

### Unit refuses to start: `RequiresMountsFor` dependency failed

`llama-swap.service` is ordered after `share-Skylab-LLMS.mount`. If MEDIAS or
the `@llms` subvolume is missing, the service does not start. Check
`systemctl status share-Skylab-LLMS.mount` and `dmesg | grep MEDIAS`.

### `libvulkan.so.1` / Vulkan

```bash
readlink -f /run/opengl-driver/lib/libvulkan.so.1
ls -l /run/opengl-driver/share/vulkan/icd.d/
vulkaninfo --summary | grep -iE 'deviceName|driverName'
```

If `vulkaninfo` sees `AMD RADV VEGA12` but llama-server reports
`No devices found`, check the `render` group membership of `llama-swap` and
that the service was restarted after the change.

### Generation times out behind Nginx

`proxy_buffering off` is required for streaming; timeouts are 600 s in the
module. For very long prompts raise `proxy_read_timeout`.

### Unload / swap behaviour

`globalTTL: 900` unloads an idle model after 15 minutes. Manual:

```bash
curl -X POST http://127.0.0.1:9931/api/models/unload
curl -X POST http://127.0.0.1:9931/api/models/unload/qwen3.5-2b
```
