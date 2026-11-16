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
