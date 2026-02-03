{ config, pkgs, lib, ... }:

let
  zrok_dns_zone = "skylab.quest";
  ziti_ctrl_port = 1280;
  zrok_ctrl_port = 18080;

  # Container UIDs from official images
  ziti_uid = 2171; # 'ziti' user in openziti/ziti-cli
  zrok_uid = 2171; # Many OpenZiti images share this UID
in
{
  # zrok Infrastructure & Homepage
  # This module implements a self-hosted zrok instance using OCI containers.
  # Permissions are handled via UIDs to allow containers to run as non-root.

  virtualisation.oci-containers.containers = {
    # 1. OpenZiti Controller & Router (Quickstart)
    ziti-controller = {
      image = "openziti/ziti-cli:latest";
      hostname = "ziti.${zrok_dns_zone}";
      extraOptions = [ "--network=zrok-net" ];
      environmentFiles = [ "/var/lib/secrets/zrok/controller.env" ];
      environment = {
        ZITI_CTRL_ADVERTISED_ADDRESS = "ziti.${zrok_dns_zone}";
        ZITI_CTRL_ADVERTISED_PORT = "${toString ziti_ctrl_port}";
      };
      volumes = [ "/var/lib/ziti:/persistent" ];
      cmd = [ "edge" "quickstart" "controller" "--home" "/persistent" ];
      ports = [ 
        "${toString ziti_ctrl_port}:${toString ziti_ctrl_port}"
        "10080:10080" # Edge API
        "3022:3022"  # Router
      ];
    };

    # 2. zrok Controller
    zrok-controller = {
      image = "openziti/zrok:latest";
      dependsOn = [ "ziti-controller" ];
      extraOptions = [ "--network=zrok-net" ];
      environmentFiles = [ "/var/lib/secrets/zrok/controller.env" ];
      volumes = [
        "/var/lib/zrok-controller:/var/lib/zrok-controller"
        "/var/lib/ziti:/persistent" 
      ];
      cmd = [ "controller" "/var/lib/zrok-controller/config.yml" ];
    };

    # 3. zrok Frontend (Public Access & OAuth)
    zrok-frontend = {
      image = "openziti/zrok:latest";
      dependsOn = [ "zrok-controller" ];
      extraOptions = [ "--network=zrok-net" ];
      ports = [
        "80:8080"
        "443:8080"
      ];
      environmentFiles = [ "/var/lib/secrets/zrok/frontend.env" ];
      volumes = [ "/var/lib/zrok-frontend:/var/lib/zrok-frontend" ];
      cmd = [ "access" "public" "/var/lib/zrok-frontend/config.yml" ];
    };
  };

  # Configuration Generator
  # Generates YAML configs from environment variables before containers start
  systemd.services.zrok-init = {
    description = "Initialize zrok and Ziti configuration files";
    wantedBy = [ "multi-user.target" ];
    before = let 
      backend = config.virtualisation.oci-containers.backend;
    in [ "${backend}-ziti-controller.service" "${backend}-zrok-controller.service" ];
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # 1. Ensure directories and network exist
      mkdir -p /var/lib/ziti /var/lib/zrok-controller /var/lib/zrok-frontend
      podman network inspect zrok-net >/dev/null 2>&1 || podman network create zrok-net

      # 2. Load Secrets for Config Generation
      if [ -f /var/lib/secrets/zrok/controller.env ]; then
        source /var/lib/secrets/zrok/controller.env
      else
        echo "Error: /var/lib/secrets/zrok/controller.env not found. Run generate-zrok-secrets.sh first."
        exit 1
      fi

      # 4. Generate zrok Controller Config
      cat <<EOF > /var/lib/zrok-controller/config.yml
v: 4
admin:
  secrets: ["$ZROK_ADMIN_TOKEN"]
endpoint:
  host: 0.0.0.0
  port: ${toString zrok_ctrl_port}
store:
  path: /var/lib/zrok-controller/sqlite3.db
  type: sqlite3
ziti:
  api_endpoint: https://ziti.${zrok_dns_zone}:${toString ziti_ctrl_port}/edge/management/v1
  username: admin
  password: "$ZITI_PWD"
EOF

      # 5. Generate zrok Frontend Config
      if [ -f /var/lib/secrets/zrok/frontend.env ]; then
        source /var/lib/secrets/zrok/frontend.env
      fi
      
      cat <<EOF > /var/lib/zrok-frontend/config.yml
v: 4
host_match: ${zrok_dns_zone}
address: 0.0.0.0:8080
oauth:
  bind_address: 0.0.0.0:8081
  endpoint_url: https://oauth.${zrok_dns_zone}
  cookie_domain: ${zrok_dns_zone}
  signing_key: "''${ZROK_OAUTH_HASH_KEY:-placeholder_32_chars_long_key_0123}"
  encryption_key: "''${ZROK_OAUTH_HASH_KEY:-placeholder_32_chars_long_key_0123}"
  providers:
    - name: google
      type: google
      client_id: "''${ZROK_OAUTH_GOOGLE_CLIENT_ID:-placeholder}"
      client_secret: "''${ZROK_OAUTH_GOOGLE_CLIENT_SECRET:-placeholder}"
EOF
      
      # 6. Set correct ownership for containers
      chown -R ${toString ziti_uid}:${toString ziti_uid} /var/lib/ziti
      chown -R ${toString zrok_uid}:${toString zrok_uid} /var/lib/zrok-controller /var/lib/zrok-frontend
      
      chmod 600 /var/lib/zrok-controller/config.yml /var/lib/zrok-frontend/config.yml
    '';
  };

  # Storage and Firewall
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/zrok 0700 root root -"
    "d /var/lib/ziti 0755 ${toString ziti_uid} ${toString ziti_uid} -"
    "d /var/lib/zrok-controller 0700 ${toString zrok_uid} ${toString zrok_uid} -"
    "d /var/lib/zrok-frontend 0700 ${toString zrok_uid} ${toString zrok_uid} -"
  ];


  networking.firewall.allowedTCPPorts = [ 80 443 ziti_ctrl_port 3022 10080 ];

  # Install zrok CLI on the host for management
  environment.systemPackages = [ pkgs.zrok ];
}
