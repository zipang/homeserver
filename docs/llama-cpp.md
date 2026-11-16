# llama.cpp (llama-cpp)

## Overview

[`llama.cpp`](https://github.com/ggml-org/llama.cpp) is a lightweight C/C++
inference engine for LLaMA-family (and other) GGUF models. On SKYLAB it runs as
the `llama-cpp` NixOS service: `llama-server` listens on
`127.0.0.1:9931` and serves an OpenAI-compatible HTTP API plus a built-in chat
Web UI, accelerated by the AMD Radeon RX Vega M GH. Nginx front-ends it at
`https://llama.<privateDomain>` (see `server.privateDomain`).

Configured in **`modules/services/llama-cpp.nix`**, using the `nixos-25.11`
module API (`model`, `host`, `port`, `extraFlags`) — **not** the newer
RFC42 `settings` option, which only exists in `nixos-unstable`. The *package*
comes from `nixpkgs-unstable` (see "Model" below).

The default model is **Qwen3.5-2B** (vision-language, image + video input,
Apache-2.0): 2.27B parameters, 262,144-token native context, ~1.28 GB at
Q4_K_M plus a ~0.67 GB vision projector (`mmproj`).

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
upstream model is unified), the service loads **both** files.

Related pages: [Jellyfin](./jellyfin.md) (other GPU-accelerated media service),
[Monitoring](./monitoring.md).

### Why Vulkan and not ROCm?

The RX Vega M GH is a Vega 12 part (`gfx904`), which is **not** in ROCm's
supported GPU list. `pkgs.llama-cpp-rocm` can sometimes be coerced with
`HSA_OVERRIDE_GFX_VERSION=9.0.0`, but it is unsupported and breaks between ROCm
releases. The Mesa RADV Vulkan backend is officially supported, ships in
`nixpkgs` as `llama-cpp-vulkan`, and generally matches or beats ROCm on this
generation of hardware.

`hardware.graphics.enable` is required: it installs the RADV driver and the
Vulkan ICD JSON files under `/run/opengl-driver`, which the (unwrapped)
`llama-server` binary discovers at runtime.

### Why the package comes from nixpkgs-unstable

Qwen3.5 uses the `qwen35` GGUF architecture (hybrid Gated DeltaNet + attention).
The `llama-cpp` in `nixos-25.11` is build **b6981** and predates it, so it fails
with `unknown model architecture: qwen35`. `pkgs-unstable.llama-cpp-vulkan` is
recent enough; the NixOS *module* still comes from 25.11, so the option names
(`model`, `port`, ...) remain the stable ones.

### Why a static user instead of DynamicUser?

The stock 25.11 unit runs the server with `DynamicUser = true` and no
supplementary groups. Such a user cannot open `/dev/dri/renderD128` (owned by
`root:render`), so GPU offload silently falls back to CPU. The module overrides
this with a static `llama-cpp` user in the `video`, `render`, and `users`
groups: `DynamicUser` and `PrivateUsers` are forced off, and a `StateDirectory`
keeps `/var/lib/llama-cpp` writable for runtime state (models themselves live
on MEDIAS, see below).

## Configuration Reference

* NixOS module options (`nixos-25.11`): [`services.llama-cpp`](https://search.nixos.org/options?channel=25.11&query=services.llama-cpp)
* Packages: [`llama-cpp-vulkan` (unstable)](https://search.nixos.org/packages?channel=unstable&query=llama-cpp-vulkan) · [`huggingface-hub`](https://search.nixos.org/packages?channel=25.11&query=huggingface-hub)
* Default model: [`unsloth/Qwen3.5-2B-GGUF`](https://huggingface.co/unsloth/Qwen3.5-2B-GGUF) (upstream [Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B))
* Vision support in llama.cpp: [multimodal docs](https://github.com/ggml-org/llama.cpp/blob/master/docs/multimodal.md)
* Graphics stack: [`hardware.graphics.enable`](https://search.nixos.org/options?channel=25.11&query=hardware.graphics.enable)
* Upstream server docs: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md>
* Server flags: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md#usage>
* NixOS Wiki: <https://wiki.nixos.org/wiki/Llama-cpp>

## Full Configuration Template

```nix
# modules/services/llama-cpp.nix
{ config, pkgs, pkgs-unstable, lib, ... }:

let
  # Shared model library on the MEDIAS drive (btrfs subvolume @llms).
  modelsDir = "/share/Skylab/LLMS";

  # One model per service instance on nixos-25.11.
  # Qwen3.5-2B: vision-capable, Apache-2.0, ~1.28 GB at Q4_K_M.
  modelFile = "${modelsDir}/Qwen3.5-2B-Q4_K_M.gguf";
  mmprojFile = "${modelsDir}/mmproj-F16.gguf";
in
{
  services.llama-cpp = {
    enable = true;

    # nixos-25.11's llama-cpp (b6981) predates the `qwen35` architecture, so
    # the package must come from nixpkgs-unstable.
    package = pkgs-unstable.llama-cpp-vulkan; # Vulkan for Vega 12 (gfx904)

    model = modelFile;
    host = "127.0.0.1"; # LAN access goes through Nginx only
    port = 9931;
    openFirewall = false;

    extraFlags = [
      "--n-gpu-layers" "999" # offload all layers; spills to CPU if VRAM is short
      "--ctx-size" "8192"
      "--jinja" # honour the model's built-in chat template
      "--mmproj" mmprojFile # vision projector: enables image/video input
    ];
  };

  # GPU access + shared-library mount ordering.
  systemd.services.llama-cpp = {
    unitConfig.RequiresMountsFor = [ modelsDir ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      User = "llama-cpp";
      Group = "llama-cpp";
      SupplementaryGroups = [ "video" "render" "users" ];
      StateDirectory = "llama-cpp";
      RestartSec = lib.mkForce 30;
    };
  };

  users.groups.llama-cpp = { };
  users.users.llama-cpp = {
    isSystemUser = true;
    group = "llama-cpp";
    extraGroups = [ "video" "render" "users" ];
    home = "/var/lib/llama-cpp";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = false;
    # Guarantees /run/opengl-driver/lib/libvulkan.so.1 exists.
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
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  environment.systemPackages = [
    pkgs-unstable.llama-cpp-vulkan # same build as the service
    pkgs.vulkan-loader
    pkgs.vulkan-tools # `vulkaninfo`
    pkgs.huggingface-hub
  ];
}
```

## Operational Guides

### Where models live

Models are plain `.gguf` files stored in the shared library
**`/share/Skylab/LLMS/`**. That path is a dedicated Btrfs subvolume
(`@llms`) on the **MEDIAS** drive, mounted by `modules/system/storage.nix`:

```nix
fileSystems."/share/Skylab/LLMS" = {
  device = "/dev/disk/by-label/MEDIAS";
  fsType = "btrfs";
  options = [ "subvol=@llms" "compress=zstd" "noatime" ];
};
```

Because `/share/Skylab` is already exported over NFS with `crossmnt`, the
subvolume is **automatically published to the LAN** as
`/share/Skylab/LLMS` — no separate export is needed, and other services can
mount or read it the same way.

The directory is `2775 zipang:users` (setgid, group-writable) via
`systemd.tmpfiles.rules`, and `llama-cpp` is a member of `users`, so:

* you download models as `zipang` (no `sudo`);
* the service reads them with group permissions.

#### One-time creation on SKYLAB

The subvolume does not exist yet on an already-installed machine:

```bash
sudo mkdir -p /mnt/medias
sudo mount /dev/disk/by-label/MEDIAS /mnt/medias
sudo btrfs subvolume create /mnt/medias/@llms
sudo umount /mnt/medias
```

Then rebuild (`sudo nixos-rebuild switch`): the mount unit and the tmpfiles
ownership rule are applied together. Finally, initialize the library and fetch
the default model:

```bash
init-llms
sudo systemctl restart llama-cpp.service
```

### SSD or HDD for the model directory?

Inference is compute-bound (GPU), so **storage speed only matters for cold
starts and model swaps**, not for token generation:

* llama.cpp `mmap`s the GGUF and pages it in on demand; after the first load it
  lives in the page cache (16 GiB RAM covers one 2–8 GB model).
* Loading is mostly **sequential** (~150–200 MB/s on a HDD, i.e. ~30 s for a
  5 GB file; a few seconds on an SSD).
* Downloads are one-off writes; they do not justify an SSD.

Conclusion for SKYLAB:

| Situation | Verdict |
| --- | --- |
| A library of many models, loaded once and kept running | **HDD is fine** |
| Frequent restarts / model swaps (`llama-swap`, A/B tests) | SSD preferable (first-token latency) |
| Several services streaming the same files concurrently | SSD (HDD seek contention) |

If MEDIAS is a spinning disk, keep the library there and optionally copy the
*active* model to the SSD; do not split the library across two roots. Avoid
network (NFS/SMB) mounts for the service's model: `RequiresMountsFor` covers
local mounts, but network file systems add failure modes (stale handles,
timeouts) for no throughput benefit once the file is cached.

### Per-user cache (`~/.cache/huggingface/`)

`hf` defaults to `~/.cache/huggingface/hub` when you omit `--local-dir`. That
cache is personal and **is not what the service reads**. Use it only for
experiments with `llama-cli`; always pass `--local-dir /share/Skylab/LLMS`
for anything the service should see (see below). The system unit has
`ProtectHome = true`, so `/home` is invisible to it regardless.

### GPU access for your own user

The static `llama-cpp` user is in `video` and `render`, but regular accounts
are not (see `modules/system/users.nix`). To run `llama-cli` with GPU offload
as `zipang`, add yourself to those groups and re-login:

```nix
users.users.zipang.extraGroups = [ "wheel" "docker" "networkmanager" "video" "render" ];
```

### Downloading a model from Hugging Face

The recommended path is the repository script, which initializes the shared
directory (owner/mode) and downloads the default model referenced by
`modules/services/llama-cpp.nix`:

```bash
init-llms            # idempotent: skips the download if the file exists
init-llms --force    # re-download
```

It is safe to run as `zipang` (no `sudo` needed once the directory exists), and
handles being run as `root` by downloading as the owner. It also warns when
`/share/Skylab/LLMS` is not actually a mountpoint, to avoid filling the root
filesystem.

If you prefer doing it by hand (the default model is vision-capable, so it
needs **two** files):

```bash
# 1. Find available quantizations and projectors
curl -s https://huggingface.co/api/models/unsloth/Qwen3.5-2B-GGUF \
  | jq -r '.siblings[].rfilename' | grep -Ei 'gguf'

# 2. Download the text weights and the vision projector
hf download unsloth/Qwen3.5-2B-GGUF Qwen3.5-2B-Q4_K_M.gguf \
  --local-dir /share/Skylab/LLMS
hf download unsloth/Qwen3.5-2B-GGUF mmproj-F16.gguf \
  --local-dir /share/Skylab/LLMS

# 3. Verify ownership and size
ls -lh /share/Skylab/LLMS/
```

Files should end up `zipang:users` and readable by the `users` group. If you
downloaded as `root` instead, fix it:

```bash
sudo chown zipang:users /share/Skylab/LLMS/*.gguf
sudo chmod 0644 /share/Skylab/LLMS/*.gguf
```

A direct URL works too (public repos need no token):

```bash
curl -L -o /share/Skylab/LLMS/Qwen3.5-2B-Q4_K_M.gguf \
  https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf
curl -L -o /share/Skylab/LLMS/mmproj-F16.gguf \
  https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/mmproj-F16.gguf
```

> **VRAM budget.** The Vega M GH has 4 GiB of HBM2. Qwen3.5-2B at `Q4_K_M`
> (≈1.28 GB) plus `mmproj-F16` (≈0.67 GB) leaves room for an 8k–16k context.
> Images consume extra context tokens, so raise `--ctx-size` only if you lower
> the number of images per request. Larger text models still load, but layers
> spill to system RAM and generation slows down considerably.

### Selecting / changing the model

`nixos-25.11` supports **one model per service instance**, declared by
`services.llama-cpp.model` (a required option). To switch models:

1. download the new `.gguf` into `/share/Skylab/LLMS/` (or set
   `LLAMA_DEFAULT_REPO` / `LLAMA_DEFAULT_FILE` / `LLAMA_DEFAULT_MMPROJ` when
   calling `init-llms`);
2. update `modelFile` (and `mmprojFile` for vision models) in
   `modules/services/llama-cpp.nix`;
3. `sudo nixos-rebuild switch` — the unit restarts with the new model.

`init-llms` reads environment variables, so a different default is one command
away:

```bash
LLAMA_DEFAULT_REPO=unsloth/Qwen3.5-2B-GGUF \
LLAMA_DEFAULT_FILE=Qwen3.5-2B-Q5_K_M.gguf \
init-llms
```

Set `LLAMA_DEFAULT_MMPROJ` to the same value as the model's projector file for
vision models (this is the default), or to an empty string to skip it.

There is no dynamic model picker in this channel. Options for multiple models:

* run additional hand-written `systemd.services.llama-cpp-<name>` units on
  distinct ports (each mimics the generated `ExecStart`);
* use [`llama-swap`](https://github.com/mostlygeek/llama-swap) as an
  OpenAI-compatible proxy that loads/unloads models on demand;
* on `nixos-unstable`'s RFC42 rewrite, the free-form `settings` attribute (and
  `models-preset` INI) supports several models in one unit. That requires the
  whole system on unstable, not just the package.

### Start / stop / restart

The startup script is the generated systemd unit `llama-cpp.service`. Its
`ExecStart` is:

```
llama-server --log-disable --host 127.0.0.1 --port 9931 -m <modelFile> \
  --n-gpu-layers 999 --ctx-size 8192 --jinja --mmproj <mmprojFile>
```

```bash
sudo systemctl start llama-cpp.service
sudo systemctl stop llama-cpp.service
sudo systemctl restart llama-cpp.service
sudo systemctl status llama-cpp.service

sudo systemctl cat llama-cpp.service   # inspect the generated unit
```

Do **not** use `systemctl edit` for permanent changes: the file lives in
`/nix/store` and is regenerated on every rebuild. Edit the module instead.

### Adding a pre-start hook

If you want the unit to fail with a clear message when the model is missing,
add a `preStart` in the module. It only *checks* readability (the service has
no write access to the shared library) and runs as `llama-cpp`:

```nix
systemd.services.llama-cpp.preStart = ''
  test -r ${modelFile} || {
    echo "Missing model: ${modelFile}" >&2
    echo "Run: hf download <repo> <file> --local-dir ${modelsDir}" >&2
    exit 1
  }
'';
```

### Web UI and OpenAI-compatible endpoints

`llama-server` ships a built-in browser UI at **`/`** and the API under
**`/v1`**. Both are served by the same Nginx vhost, so with
`server.privateDomain = "skylab.local"` they are available on the LAN as:

| URL | Purpose |
| --- | --- |
| `https://llama.skylab.local/` | Built-in chat Web UI (no dashboard to install) |
| `https://llama.skylab.local/v1/models` | List the loaded model |
| `https://llama.skylab.local/v1/chat/completions` | OpenAI chat-completions API (streaming supported) |
| `https://llama.skylab.local/v1/completions` | Legacy completions API |
| `https://llama.skylab.local/v1/embeddings` | Embeddings (if the model supports it) |
| `https://llama.skylab.local/health` | Liveness probe |

The vhost name comes from `config.server.privateDomain`, not a hardcoded
string: if your internal domain is not `skylab.local`, the host is
`llama.<privateDomain>`. Point any OpenAI-compatible client at
`https://llama.skylab.local/v1` with any non-empty API key (the server does not
require one; authentication is the LAN allowlist on the vhost).

```bash
# Web UI over the proxy (opens the built-in chat)
curl -s https://llama.skylab.local/ \
  --cacert /var/lib/secrets/certs/skylab-ca.crt | head

# OpenAI client style
export OPENAI_BASE_URL=https://llama.skylab.local/v1
export OPENAI_API_KEY=local
```

### Test the API

```bash
# Health / loaded model
curl -s http://127.0.0.1:9931/v1/models | jq

# Chat completion
curl -s http://127.0.0.1:9931/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local",
    "messages": [{ "role": "user", "content": "Hello" }],
    "max_tokens": 64
  }' | jq -r '.choices[0].message.content'

# Through the reverse proxy (from another LAN machine)
curl -s https://llama.skylab.local/v1/models \
  --cacert /var/lib/secrets/certs/skylab-ca.crt
```

### Vision (image input)

Qwen3.5-2B accepts images because the service passes `--mmproj`. The built-in
Web UI has an attach button; from the API, send an OpenAI-style content array
with a base64 data URL:

```bash
IMG=$(base64 -w0 photo.jpg)
curl -s http://127.0.0.1:9931/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"local\",
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

Video input follows the same content-array shape with `"type": "video_url"`.
Each image/video frame consumes context tokens: keep `--ctx-size` at 8192 for a
single image, or lower the image resolution/count if you get truncation.

## Headless Operations & Troubleshooting

### Logs and status

```bash
journalctl -u llama-cpp.service -f
journalctl -u llama-cpp.service -b --no-pager | tail -100
systemctl status llama-cpp.service
```

### Port and process checks

```bash
ss -ltnp | grep 9931
systemctl show -p ExecStart,User,Group,StateDirectory llama-cpp.service
```

### Verifying `libvulkan.so.1` and the Vulkan stack

These checks must run **on SKYLAB** (over SSH), after a
`sudo nixos-rebuild switch`; they cannot be verified from the staging repo.

```bash
# 1. The loader itself — provided by hardware.graphics.extraPackages
readlink -f /run/opengl-driver/lib/libvulkan.so.1
# -> /nix/store/...-vulkan-loader-.../lib/libvulkan.so.1

# 2. The ICD manifest (RADV) — required to see the GPU
ls -l /run/opengl-driver/share/vulkan/icd.d/

# 3. llama-server's own view of the loader (RPATH)
ldd "$(command -v llama-server)" | grep -i vulkan

# 4. The GPU is enumerated
vulkaninfo --summary | grep -iE 'deviceName|driverName|apiVersion'
# -> deviceName = AMD RADV VEGA12 (RADV VEGA12)
```

If step 1 prints "No such file or directory", `hardware.graphics.enable` or
`extraPackages = [ pkgs.vulkan-loader ]` is missing from the module. If step 1
succeeds but step 2 is empty, Mesa/RADV is not in the driver environment.

### GPU / Vulkan verification

```bash
vulkaninfo --summary        # should list the "AMD RADV VEGA12" device
journalctl -u llama-cpp.service | grep -iE 'vulkan|backend|device'
ls -l /dev/dri/             # renderD128 must exist
id llama-cpp                # must include video and render
```

The server logs a line like `ggml_vulkan: Found 1 Vulkan devices` when offload
works. If it says `ggml_vulkan: No devices found`, Vulkan cannot see the GPU:
check `hardware.graphics.enable`, the `render` group membership, and that the
unit was rebuilt after the change.

### `error while loading shared libraries: libvulkan.so.1`

The loader is missing from both the package closure and the graphics driver
environment — usually because the module was added without a rebuild. Confirm
with `readlink -f /run/opengl-driver/lib/libvulkan.so.1`, rebuild, and check
again. The module adds `vulkan-loader` to `hardware.graphics.extraPackages`
exactly for this case.

### `ggml_vulkan: No devices found` right after boot

The loader is present but `/run/opengl-driver/share/vulkan/icd.d` has no RADV
manifest, or the unit cannot read it. Check `ls /run/opengl-driver/share/vulkan/icd.d/`
and the `render` group membership of `llama-cpp` (see above).

### `unknown model architecture: qwen35`

The service is still using the `nixos-25.11` `llama-cpp` (build b6981), which
predates Qwen3.5. Set `package = pkgs-unstable.llama-cpp-vulkan;` and rebuild.
Check which binary runs with
`systemctl show -p ExecStart llama-cpp.service | grep -o '/nix/store[^ ]*'`.

### `failed to load model from ...` / `No such file or directory`

Check the two usual causes in order:

```bash
# 1. Is the MEDIAS subvolume actually mounted there?
findmnt /share/Skylab/LLMS
# 2. Can the service user read the file?
sudo -u llama-cpp test -r /share/Skylab/LLMS/<file>.gguf && echo OK
ls -ld /share/Skylab/LLMS        # expect drwxrwsr-x zipang users
```

If the mount is missing, the one-time `btrfs subvolume create` was skipped (see
"Where models live"). If permissions are wrong, re-apply the tmpfiles rule with
`sudo systemd-tmpfiles --create` and re-download as `zipang`.

### Unit refuses to start: `RequiresMountsFor` dependency failed

`llama-cpp.service` is ordered after `share-Skylab-LLMS.mount`. If MEDIAS is
absent or the subvolume is missing, the service does not start (by design: it
must not silently read an empty underlying directory). Verify with
`systemctl status share-Skylab-LLMS.mount` and `dmesg | grep MEDIAS`.

### `Address already in use` on 9931

Another process grabbed the port. Identify it with `ss -ltnp | grep 9931`, then
either stop it or change `services.llama-cpp.port` (and the Nginx `proxyPass`
in the same module).

### 403 from Nginx

The request did not come from `192.168.1.0/24` or loopback. The vhost has no
application authentication, so the allowlist is the only boundary — widen it in
the module if your LAN uses another subnet or if you access it over Netbird.

### Generation times out behind Nginx

`proxy_read_timeout`/`proxy_send_timeout` are raised to 600 s in the module.
For very long prompts raise them further; `proxy_buffering off` is required for
streamed responses.

### Images are rejected or ignored

`--mmproj` is missing, points to a non-existent file, or the service was not
restarted. Verify the flag and the file:

```bash
systemctl cat llama-cpp.service | grep -o -- '--mmproj [^ ]*'
ls -lh /share/Skylab/LLMS/mmproj-F16.gguf
```

### Low GPU offload

Check `journalctl` for `offloaded X/Y layers`. If Y is smaller than expected,
the model plus context exceeds 4 GiB of VRAM: lower `--n-gpu-layers`, reduce
`--ctx-size`, or pick a smaller quantization. `--n-gpu-layers 999` asks for
everything and lets llama.cpp spill the remainder to the CPU.
