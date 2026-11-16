# llama.cpp (llama-cpp)

## Overview

[`llama.cpp`](https://github.com/ggml-org/llama.cpp) is a lightweight C/C++
inference engine for LLaMA-family (and other) GGUF models. On SKYLAB it runs as
the `llama-cpp` NixOS service: `llama-server` listens on
`127.0.0.1:8080` and serves an OpenAI-compatible HTTP API, accelerated by the
AMD Radeon RX Vega M GH. Nginx front-ends it at
`https://llama.<privateDomain>` (see `server.privateDomain`).

Configured in **`modules/services/llama-cpp.nix`**, using the `nixos-25.11`
module API (`model`, `host`, `port`, `extraFlags`) — **not** the newer
RFC42 `settings` option, which only exists in `nixos-unstable`.

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
* Packages: [`llama-cpp-vulkan`](https://search.nixos.org/packages?channel=25.11&query=llama-cpp-vulkan) · [`llama-cpp-rocm`](https://search.nixos.org/packages?channel=25.11&query=llama-cpp-rocm) · [`huggingface-hub`](https://search.nixos.org/packages?channel=25.11&query=huggingface-hub)
* Graphics stack: [`hardware.graphics.enable`](https://search.nixos.org/options?channel=25.11&query=hardware.graphics.enable)
* Upstream server docs: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md>
* Server flags: <https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md#usage>
* NixOS Wiki: <https://wiki.nixos.org/wiki/Llama-cpp>

## Full Configuration Template

```nix
# modules/services/llama-cpp.nix
{ config, pkgs, lib, ... }:

let
  # Shared model library on the MEDIAS drive (btrfs subvolume @llms).
  modelsDir = "/share/Skylab/LLMS";

  # One model per service instance on nixos-25.11.
  # The 4 GiB HBM2 of the Vega M GH fits roughly a 3B model at Q4_K_M.
  modelFile = "${modelsDir}/Qwen2.5-3B-Instruct-Q4_K_M.gguf";
in
{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan; # Vulkan for Vega 12 (gfx904)
    model = modelFile;
    host = "127.0.0.1"; # LAN access goes through Nginx only
    port = 8080;
    openFirewall = false;

    extraFlags = [
      "--n-gpu-layers" "999" # offload all layers; spills to CPU if VRAM is short
      "--ctx-size" "8192"
      "--jinja" # honour the model's built-in chat template
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
      proxyPass = "http://127.0.0.1:8080";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    llama-cpp-vulkan
    vulkan-loader
    vulkan-tools # `vulkaninfo`
    huggingface-hub
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
ownership rule are applied together.

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

`huggingface-hub` provides the `hf` CLI (it is in `environment.systemPackages`).
Run the download **as yourself** (`zipang`): the shared directory is
group-writable and the service reads through the `users` group.

```bash
# 1. Find available quantizations (needs jq, optional)
curl -s https://huggingface.co/api/models/bartowski/Qwen2.5-3B-Instruct-GGUF \
  | jq -r '.siblings[].rfilename' | grep -i gguf

# 2. Download one file into the shared library
hf download \
  bartowski/Qwen2.5-3B-Instruct-GGUF \
  Qwen2.5-3B-Instruct-Q4_K_M.gguf \
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
curl -L -o /share/Skylab/LLMS/model.gguf \
  https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf
```

> **VRAM budget.** The Vega M GH has 4 GiB of HBM2. Prefer 3B-class models at
> `Q4_K_M` (≈2 GB) or 7B at `Q3_K_M`. Larger files still load, but layers spill
> to system RAM and generation slows down considerably.

### Selecting / changing the model

`nixos-25.11` supports **one model per service instance**, declared by
`services.llama-cpp.model` (a required option). To switch models:

1. download the new `.gguf` into `/share/Skylab/LLMS/`;
2. update `modelFile` in `modules/services/llama-cpp.nix`;
3. `sudo nixos-rebuild switch` — the unit restarts with the new model.

There is no dynamic model picker in this channel. Options for multiple models:

* run additional hand-written `systemd.services.llama-cpp-<name>` units on
  distinct ports (each mimics the generated `ExecStart`);
* use [`llama-swap`](https://github.com/mostlygeek/llama-swap) as an
  OpenAI-compatible proxy that loads/unloads models on demand;
* upgrade the service to `nixos-unstable`, whose RFC42 rewrite adds a
  free-form `settings` attribute (and `models-preset` INI) supporting several
  models.

### Start / stop / restart

The startup script is the generated systemd unit `llama-cpp.service`. Its
`ExecStart` is:

```
llama-server --log-disable --host 127.0.0.1 --port 8080 -m <modelFile> <extraFlags...>
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

### Test the API

```bash
# Health / loaded model
curl -s http://127.0.0.1:8080/v1/models | jq

# Chat completion
curl -s http://127.0.0.1:8080/v1/chat/completions \
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

## Headless Operations & Troubleshooting

### Logs and status

```bash
journalctl -u llama-cpp.service -f
journalctl -u llama-cpp.service -b --no-pager | tail -100
systemctl status llama-cpp.service
```

### Port and process checks

```bash
ss -ltnp | grep 8080
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

### `Address already in use` on 8080

Another process grabbed the port. Identify it with `ss -ltnp | grep 8080`, then
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

### Low GPU offload

Check `journalctl` for `offloaded X/Y layers`. If Y is smaller than expected,
the model plus context exceeds 4 GiB of VRAM: lower `--n-gpu-layers`, reduce
`--ctx-size`, or pick a smaller quantization. `--n-gpu-layers 999` asks for
everything and lets llama.cpp spill the remainder to the CPU.
