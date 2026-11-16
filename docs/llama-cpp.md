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
  NFS). The default is **Qwen3.5-2B**, vision-capable. Any new `.gguf` dropped
  in that directory is **registered automatically** by `llama-scan` (see
  [Automatic registration](#automatic-registration-llama-scan)); its llama-swap
  declaration lives in `/share/Skylab/LLMS/llama-swap.d/`.

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
{ config, pkgs, pkgs-unstable, lib, ... }:

let
  # Shared model library on the MEDIAS drive (btrfs subvolume @llms, see
  # modules/system/storage.nix). NFS publishes it as /share/Skylab/LLMS, so
  # both the models and the llama-swap configuration are editable from any
  # machine on the LAN, and they survive a NixOS reinstall.
  modelsDir = "/share/Skylab/LLMS";

  # llama-swap merges every *.yaml found here (no scan of the models itself).
  # `llama-scan` auto-registers new GGUF files, `llama-register` does it by
  # hand. One file per model: no shared file to corrupt, and dropping a file
  # is enough to add/remove a model (llama-swap polls the directory every 2 s).
  configDir = "${modelsDir}/llama-swap.d";

  llamaServer = "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server";

  # --- Seeded once (`tmpfiles` rule `C` never overwrites an existing file) ---

  globalsSeed = pkgs.writeText "llama-swap-00-globals.yaml" ''
    healthCheckTimeout: 300
    logLevel: info
    sendLoadingState: true
    startPort: 10001
    globalTTL: 900
  '';

  # Curated default: the small vision model always fits in 4 GiB of VRAM.
  # `${PORT}` must reach llama-swap verbatim.
  defaultModelSeed = pkgs.writeText "llama-swap-qwen3.5-2b.yaml" ''
    models:
      "qwen3.5-2b":
        name: "Qwen3.5-2B (vision)"
        cmd: |
          ${llamaServer}
          --host 127.0.0.1 --port ''${PORT}
          -m ${modelsDir}/Qwen3.5-2B-Q4_K_M.gguf
          --ctx-size 8192 --n-gpu-layers 999 --jinja
          --mmproj ${modelsDir}/mmproj-F16.gguf
  '';
in
{
  # llama-swap is the single front-end: it starts/stops llama-server on
  # demand, one model at a time (only 4 GiB of VRAM on the Vega M GH).
  systemd.services.llama-swap = {
    description = "llama-swap - on-demand model switching for llama.cpp";
    after = [ "network.target" "llama-scan.service" ];
    wants = [ "llama-scan.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = [ modelsDir ];

    serviceConfig = {
      Type = "simple";
      User = "llama-swap";
      Group = "llama-swap";
      SupplementaryGroups = [ "video" "render" "users" ];
      StateDirectory = "llama-swap";
      StateDirectoryMode = "2775";
      ExecStart = "${pkgs-unstable.llama-swap}/bin/llama-swap --config-dir ${configDir} --listen 127.0.0.1:9931 --watch-config";
      Restart = "on-failure";
      RestartSec = 10;

      # Hardening: only the config directory and StateDirectory are writable.
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

  # Auto-registration: read the GGUF headers of the model library and write
  # one fragment per model. Idempotent, runs on boot (before llama-swap) and
  # every 2 minutes, so a file copied over NFS/SMB shows up on its own.
  systemd.services.llama-scan = {
    description = "Register GGUF models in llama-swap's config directory";
    unitConfig.RequiresMountsFor = [ modelsDir ];
    path = [ pkgs-unstable.llama-swap ]; # enables `llama-swap --validate`
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/llama-scan}";
    };
  };

  systemd.timers.llama-scan = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
      Unit = "llama-scan.service";
    };
  };

  # Seed the config directory once. `C` never overwrites an existing file, so
  # local edits (ctx size, extra models) survive reboots and rebuilds.
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-swap 2775 llama-swap users -"
    "d ${configDir} 2775 zipang users -"
    "C ${configDir}/00-globals.yaml 0664 root users - ${globalsSeed}"
    "C ${configDir}/qwen3.5-2b.yaml 0664 root users - ${defaultModelSeed}"
    "d ${modelsDir}/.cache/huggingface 2775 zipang users -"
  ];

  users.groups.llama-swap = { };
  users.users.llama-swap = {
    isSystemUser = true;
    group = "llama-swap";
    extraGroups = [ "video" "render" "users" ];
    home = "/var/lib/llama-swap";
  };

  # Mesa/RADV driver and Vulkan ICDs under /run/opengl-driver.
  # vulkan-loader is added explicitly so /run/opengl-driver/lib/libvulkan.so.1
  # always exists, independently of llama-cpp's own RPATH.
  hardware.graphics = {
    enable = true;
    enable32Bit = false;
    extraPackages = [ pkgs.vulkan-loader ];
  };

  # --- Reverse proxy -------------------------------------------------------
  services.nginx.virtualHosts."llama.${config.server.privateDomain}" = {
    onlySSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    # No application-level authentication: keep it on the LAN.
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
        # SSE + streamed responses must not be buffered.
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  environment.systemPackages = [
    pkgs-unstable.llama-cpp-vulkan # provides llama-server / llama-cli
    pkgs-unstable.llama-swap
    pkgs.vulkan-loader
    pkgs.vulkan-tools # provides `vulkaninfo` for verification
    pkgs.python3 # `llama-scan` / `llama-register` shebang
    pkgs.python3Packages.huggingface-hub # `hf download`
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
ownership/permissions, then runs `llama-scan`, which **registers the new model
automatically**. Run it as `zipang`; it fails with a clear error if the
directory is not writable.

`llama-models` lists the local GGUF files (and the projectors) with sizes,
`llama-scan list` shows the registered model IDs.

Both download scripts go through a hidden `.staging/` directory: `hf --local-dir`
creates metadata in `<local-dir>/.cache/huggingface` and a temp file in the
parent of the destination, which fails when the destination is directly under
the root-owned `/share/Skylab`.

### llama-swap configuration

The configuration is a **directory of YAML fragments**, not a single file:

```
/share/Skylab/LLMS/
├── Qwen3.5-2B-Q4_K_M.gguf
├── Qwen3.5-4B-3D-Coder-Q4_K_M.gguf
├── mmproj-F16.gguf
├── mmproj-Qwen3.5-4B-BF16.gguf
└── llama-swap.d/
    ├── 00-globals.yaml                 # seeded by Nix
    ├── qwen3.5-2b.yaml                 # seeded by Nix (curated default)
    ├── auto-qwen3.5-4b-3d-coder.yaml   # written by llama-scan
    └── mistral-7b-instruct.yaml        # written by llama-register
```

`llama-swap` is started with `--config-dir` and **merges every `*.yaml` file**
found there (in filename order). One file per model means there is no single
big file to corrupt, and the fragments live on MEDIAS: editable over SSH, SMB
or NFS, and preserved across a NixOS reinstall.

| File | Owner | Behaviour |
| --- | --- | --- |
| `00-globals.yaml` | Nix (`tmpfiles C`) | seeded once, never overwritten |
| `qwen3.5-2b.yaml` | Nix (`tmpfiles C`) | curated default, seeded once |
| `auto-<id>.yaml` | `llama-scan` | created for new files, removed when the GGUF disappears |
| `<id>.yaml` | you / `llama-register` | never touched by `llama-scan` |

A fragment looks like this:

```yaml
models:
  "qwen3.5-4b-3d-coder":
    name: "Qwen3.5 4B 3D Coder Q4_K_M"
    cmd: |
      /run/current-system/sw/bin/llama-server
      --host 127.0.0.1 --port ${PORT}
      -m /share/Skylab/LLMS/Qwen3.5-4B-3D-Coder-Q4_K_M.gguf
      --ctx-size 4096 --n-gpu-layers 999 --jinja
      --mmproj /share/Skylab/LLMS/mmproj-Qwen3.5-4B-BF16.gguf
```

- the key (`qwen3.5-4b-3d-coder`) is the **model ID** used by API clients;
- `${PORT}` is assigned by llama-swap (10001, 10002, …), so children never
  collide;
- add `--mmproj <file>` for vision models;
- optional keys: `ttl` (per-model idle unload), `aliases`, `concurrencyLimit`,
  `env`, `capabilities`, `useModelName`.

Global keys in use: `startPort: 10001`, `globalTTL: 900`,
`healthCheckTimeout: 300`, `sendLoadingState: true`.

Model IDs must be unique across the whole directory: two fragments declaring
the same ID make the merged config invalid, so `llama-scan` skips (and prunes)
anything already declared elsewhere.

### Automatic registration (`llama-scan`)

`llama-scan` reads the **GGUF metadata header** of every `*.gguf` in the model
library (never the tensors, so it stays fast) and writes one `auto-<id>.yaml`
fragment per model:

- `general.architecture` identifies the model family (e.g. `qwen35`); files
  with the `clip` architecture are treated as vision projectors and are never
  registered as models;
- embedding architectures (`bert`, `nomic-bert`, `bge-m3`, `t5`, …) are
  skipped: llama-server would start them but they cannot answer chat requests;
- `<arch>.context_length` caps `--ctx-size` (4096 above 2 GiB of weights, 8192
  below, to keep the KV cache inside 4 GiB of VRAM);
- the vision projector is attached automatically when its family matches
  (`mmproj-Qwen3.5-4B-BF16.gguf` → `Qwen3.5-4B-*.gguf`). If two projectors
  match, nothing is attached and a warning is printed: choose one with
  `llama-register --mmproj`;
- the quantization suffix is **not** part of the ID (it stays in the display
  name): `Qwen3.5-4B-3D-Coder-Q4_K_M.gguf` → `qwen3.5-4b-3d-coder`. Two
  quantizations of the same model therefore collide; register the second one
  explicitly with `llama-register --id`.

It runs at boot (before `llama-swap` starts) and every 2 minutes via
`llama-scan.timer`, so a file copied over NFS/SMB is picked up on its own. It
is idempotent: existing fragments are never rewritten unless you pass
`--force`.

```bash
llama-scan                 # sync (what the timer runs)
llama-scan --dry-run -v    # show what would change
llama-scan --force         # regenerate the auto-* fragments
llama-scan list            # model IDs and their fragment
```

Files that should be ignored (partial downloads, non-chat models, …) are
listed in `llama-swap.d/.llama-ignore`, one glob per line:

```text
*.incomplete
Mistral-*.gguf
```

### Manual registration (`llama-register`)

Use it when the automatic defaults are not what you want (context size,
projector, ID, display name) or for a file that was not auto-registered:

```bash
llama-register <file> [--id ID] [--name NAME] [--ctx N]
                      [--mmproj FILE | --no-mmproj] [--force] [--dry-run]
```

Example:

```bash
llama-register Qwen3.5-4B-3D-Coder-Q4_K_M.gguf --ctx 8192
```

It writes `<id>.yaml` and deletes the matching `auto-*.yaml`, so a manual
fragment always wins over the auto-generated one. Deleting the file
unregisters the model.

### Persistence and reloads

**Persistent.** The fragments live on MEDIAS (the `@llms` subvolume), outside
`/nix/store`, and Nix only *seeds* `00-globals.yaml` and `qwen3.5-2b.yaml` with
the `tmpfiles` `C` rule, which **never overwrites an existing file**.
`update-nix`, `nixos-rebuild switch`, reboots and garbage collection leave them
untouched. Changing the seeded Nix values has no effect on an existing install
by design — to pick them up, delete the fragment and run
`sudo systemd-tmpfiles --create`.

**No restart needed.** `--watch-config` polls the directory every 2 seconds and
reloads on any change (it compares mtime/size, so atomic writes and editors
that rename files are handled). If the new configuration is invalid, llama-swap
logs `failed to reload config` and **keeps serving the previous one** — no
outage. To validate a fragment before saving, or to force a reload:

```bash
llama-swap --validate --config-dir /share/Skylab/LLMS/llama-swap.d
sudo systemctl kill -s HUP llama-swap.service      # reload via SIGHUP
journalctl -u llama-swap.service -n 30 | grep -i config
```

`llama-scan` and `llama-register` both run that validation after writing, so a
bad fragment is reported immediately.

### Migrating from the old single-file configuration

Previously the configuration was `/var/lib/llama-swap/config.yaml`. That file
is no longer read; the equivalent entries now live in `llama-swap.d/`. Remove
it once the new layout is in place:

```bash
sudo rm -f /var/lib/llama-swap/config.yaml
ls /share/Skylab/LLMS/llama-swap.d
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

To preload a model at startup, add to a fragment (e.g. `00-globals.yaml`):

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

`--watch-config` polls `llama-swap.d/` every 2 seconds. If nothing happens
after a save, check that the file is really in that directory and ends with
`.yaml`/`.yml`, then look at the reload logs — a syntax error (or a duplicate
model ID) is logged and the previous config is kept:

```bash
journalctl -u llama-swap.service -n 30 | grep -i config
llama-swap --validate --config-dir /share/Skylab/LLMS/llama-swap.d
```

Force a reload (or a restart if the poll is not enough):

```bash
sudo systemctl kill -s HUP llama-swap.service
```

### Auto-registration does not pick up a new file

```bash
llama-scan --dry-run -v          # what llama-scan sees and why it skips
systemctl status llama-scan.timer
journalctl -u llama-scan.service -n 20 --no-pager
llama-scan list                  # registered IDs
head -c 4 /share/Skylab/LLMS/<file>.gguf   # must be "GGUF"
```

Usual causes: the download is still `.incomplete`, the file is listed in
`.llama-ignore`, the architecture is an embedding model, or the GGUF header is
corrupt (the script then warns `cannot read GGUF header`).
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
