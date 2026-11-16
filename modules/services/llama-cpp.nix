{ config, pkgs, pkgs-unstable, lib, ... }:

let
  # Shared model library on the MEDIAS drive (btrfs subvolume @llms, see
  # modules/system/storage.nix). NFS publishes it as /share/Skylab/LLMS.
  modelsDir = "/share/Skylab/LLMS";

  # Models pre-declared in the seed configuration. `scripts/init-llms`
  # downloads them; `scripts/llama-download` fetches new ones.
  # Adding an entry here only affects fresh installs: the live config is
  # /var/lib/llama-swap/config.yaml and is meant to be edited at runtime.
  seedModels = {
    "qwen3.5-2b" = {
      name = "Qwen3.5-2B (vision)";
      file = "Qwen3.5-2B-Q4_K_M.gguf";
      mmproj = "mmproj-F16.gguf";
      ctx = 8192;
    };
  };

  llamaServer = "${pkgs-unstable.llama-cpp-vulkan}/bin/llama-server";

  # YAML seed, copied to /var/lib/llama-swap/config.yaml on first boot only.
  # `${PORT}` must reach llama-swap verbatim, hence the `''${` escape.
  configSeed = pkgs.writeText "llama-swap-config.yaml" (lib.generators.toYAML { } {
    healthCheckTimeout = 300;
    logLevel = "info";
    sendLoadingState = true;
    startPort = 10001;
    globalTTL = 900; # unload a model after 15 min of inactivity
    models = lib.mapAttrs (id: m: {
      inherit (m) name;
      cmd = ''
        ${llamaServer}
        --host 127.0.0.1 --port ''${PORT}
        -m ${modelsDir}/${m.file}
        --ctx-size ${toString m.ctx}
        --n-gpu-layers 999
        --jinja
      '' + lib.optionalString ((m.mmproj or null) != null) "--mmproj ${modelsDir}/${m.mmproj}\n";
    }) seedModels;
  });

  configPath = "/var/lib/llama-swap/config.yaml";
in
{
  # llama-swap is the single front-end: it starts/stops llama-server on
  # demand, one model at a time (only 4 GiB of VRAM on the Vega M GH).
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

      # Hardening: the models stay read-only, only StateDirectory is writable.
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

  # Seed the (mutable, watched) config once. `C` never overwrites an existing
  # file, so runtime edits survive reboots and rebuilds.
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
    pkgs.python3Packages.huggingface-hub # `hf download`
  ];
}
