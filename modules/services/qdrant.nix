{
  config,
  pkgs,
  ...
}:

let
  qdrant = pkgs.callPackage ../../packages/qdrant.nix { };
  qdrant-web-ui = pkgs.callPackage ../../packages/qdrant-web-ui.nix { };
in
{
  # Qdrant Service Configuration (NixOS 25.11)
  # Documentation: https://search.nixos.org/options?channel=25.11&query=services.qdrant
  services.qdrant = {
    enable = true;

    # Pin both the server and the dashboard: nixpkgs 25.11 ships an older
    # Qdrant (1.15.x) than the version measured by the RAG project.
    package = qdrant;
    webUIPackage = qdrant-web-ui;

    settings = {
      service = {
        # Bind to loopback only. LAN traffic reaches Qdrant exclusively
        # through the Nginx TLS reverse proxy below.
        host = "127.0.0.1";
        http_port = 6333;
        grpc_port = 6334;

        # The dashboard is served same-origin by Qdrant, so CORS is not needed.
        enable_cors = false;
      };

      storage = {
        storage_path = "/var/lib/qdrant/storage";
        snapshots_path = "/var/lib/qdrant/snapshots";
      };

      telemetry_disabled = true;
    };
  };

  # Nginx Reverse Proxy Configuration - HTTPS only, no HTTP listener.
  #
  # Qdrant has no application-level authentication in this setup. The
  # allowlist below is the network boundary: only the local LAN and the
  # loopback may reach the dashboard/API. Adjust the subnet if your access
  # path changes (Netbird, Docker bridge, ...).
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
