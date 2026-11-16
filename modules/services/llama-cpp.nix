{ config, pkgs, lib, ... }:

let
  # Shared model library on the MEDIAS drive (btrfs subvolume @llms, see
  # modules/system/storage.nix). NFS publishes it as /share/Skylab/LLMS.
  modelsDir = "/share/Skylab/LLMS";

  # One model per service instance on nixos-25.11 (see docs/llama-cpp.md).
  # The 4 GiB HBM2 of the Vega M GH fits roughly a 3B model at Q4_K_M.
  modelFile = "${modelsDir}/Qwen2.5-3B-Instruct-Q4_K_M.gguf";
in
{
  # llama.cpp inference server (OpenAI-compatible API)
  services.llama-cpp = {
    enable = true;

    # Vulkan is the reliable GPU backend on Vega 12 (gfx904), which ROCm does
    # not officially target. Swap for pkgs.llama-cpp-rocm only if you know
    # your GPU is supported (or set HSA_OVERRIDE_GFX_VERSION).
    package = pkgs.llama-cpp-vulkan;

    model = modelFile;
    host = "127.0.0.1"; # LAN traffic goes through Nginx only
    port = 8080;
    openFirewall = false;

    extraFlags = [
      "--n-gpu-layers" "999" # offload every layer; spills to CPU if VRAM is short
      "--ctx-size" "8192"
      "--jinja" # honour the model's built-in chat template
    ];
  };

  # --- GPU access and persistence -----------------------------------------
  # The stock 25.11 unit runs as a DynamicUser with no supplementary groups,
  # so it cannot open /dev/dri/renderD128. Use a static user in video/render
  # and keep the persistent state directory.
  systemd.services.llama-cpp = {
    # Never start before the MEDIAS model subvolume is mounted.
    unitConfig.RequiresMountsFor = [ modelsDir ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      User = "llama-cpp";
      Group = "llama-cpp";
      SupplementaryGroups = [ "video" "render" "users" ];
      StateDirectory = "llama-cpp"; # /var/lib/llama-cpp (runtime state)
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

    # The API has no application-level authentication: keep it on the LAN.
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
        # Token generation is slow and streamed: do not buffer or time out.
        proxy_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
      '';
    };
  };

  environment.systemPackages = with pkgs; [
    llama-cpp-vulkan
    vulkan-loader
    vulkan-tools # provides `vulkaninfo` for verification
    huggingface-hub # `hf download` to fetch GGUF files
  ];
}
