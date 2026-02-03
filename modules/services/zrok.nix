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

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

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
        ZITI_CTRL_LISTENER_ADDRESS = "0.0.0.0";
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
        "10081:8080" # Public Access
        "10082:8081" # OAuth Callback
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
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30s";
    };
    path = [ pkgs.coreutils ];
    script = ''
      set -ex
      # 1. Load Secrets for Config Generation
      if [ -f /var/lib/secrets/zrok/controller.env ]; then
        source /var/lib/secrets/zrok/controller.env
      else
        echo "Error: /var/lib/secrets/zrok/controller.env not found."
        exit 1
      fi

      # 2. Generate zrok Controller Config
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

      # 3. Generate zrok Frontend Config
      if [ -f /var/lib/secrets/zrok/frontend.env ]; then
        source /var/lib/secrets/zrok/frontend.env
      fi
      
      cat <<EOF > /var/lib/zrok-frontend/config.yml
v: 4
host_match: ${zrok_dns_zone}
address: 0.0.0.0:8080
ziti_identity: "/var/lib/zrok-frontend/identity.json"
ziti:
  api_endpoint: https://ziti.${zrok_dns_zone}:${toString ziti_ctrl_port}/edge/management/v1
  username: admin
  password: "$ZITI_PWD"
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
      
      # 4. Set correct ownership for the new config files
      chown ${toString zrok_uid}:${toString zrok_uid} /var/lib/zrok-controller/config.yml /var/lib/zrok-frontend/config.yml
      chmod 600 /var/lib/zrok-controller/config.yml /var/lib/zrok-frontend/config.yml
    '';
  };

  # Storage and Firewall
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/zrok 0700 root root -"
    "d /var/lib/ziti 0755 ${toString ziti_uid} ${toString ziti_uid} -"
    "d /var/lib/zrok-controller 0755 ${toString zrok_uid} ${toString zrok_uid} -"
    "d /var/lib/zrok-frontend 0755 ${toString zrok_uid} ${toString zrok_uid} -"
  ];


  networking.firewall.allowedTCPPorts = [ 80 443 ziti_ctrl_port 3022 10080 10081 10082 ];

  # Dedicated service for creating the podman network
  # This is separated from zrok-init to avoid deadlocks
  systemd.services.zrok-network = {
    description = "Create zrok podman network";
    after = [ "network.target" ];
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      podman network inspect zrok-net >/dev/null 2>&1 || podman network create zrok-net
    '';
  };

  # Install zrok CLI on the host for management
  environment.systemPackages = [ pkgs.zrok ];

  # Slow down restart loop to let Ziti initialize
  systemd.services."podman-zrok-controller".serviceConfig.RestartSec = "10s";
  systemd.services."podman-zrok-frontend".serviceConfig.RestartSec = "10s";

  # Ensure the container services start after our helper services
  systemd.services."podman-ziti-controller".after = [ "zrok-init.service" "zrok-network.service" ];
  systemd.services."podman-zrok-controller".after = [ "zrok-init.service" "zrok-network.service" "podman-ziti-controller.service" ];
  systemd.services."podman-zrok-frontend".after = [ "zrok-init.service" "zrok-network.service" "podman-zrok-controller.service" "zrok-bootstrap.service" ];

  # Automated Bootstrap Service
  # This runs after the controller is up and registers the frontend identity if missing.
  systemd.services.zrok-bootstrap = {
    description = "Automated zrok frontend bootstrap";
    after = [ "podman-zrok-controller.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.podman pkgs.gnugrep pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "5min"; # Allow time for image pulling
    };
    script = ''
      set -ex
      
      # 1. Wait for the container to actually exist
      echo "Waiting for zrok-controller container to exist..."
      until podman ps -a --format "{{.Names}}" | grep -q "^zrok-controller$"; do
        echo "Container zrok-controller not found yet. Sleeping..."
        sleep 5
      done

      # 2. Wait for it to be running
      echo "Waiting for zrok-controller to be running..."
      until [ "$(podman inspect -f '{{.State.Running}}' zrok-controller)" == "true" ]; do
        echo "Container zrok-controller is not running yet. Sleeping..."
        sleep 5
      done

      # 3. Proceed with bootstrap if needed
      if [ ! -f /var/lib/zrok-frontend/identity.json ]; then
        echo "Registering public frontend identity in OpenZiti..."
        # We retry because the Ziti API inside the container takes a few seconds to be ready
        until podman exec zrok-controller zrok admin bootstrap /var/lib/zrok-frontend/config.yml; do
          echo "Waiting for OpenZiti API to be ready..."
          sleep 5
        done
        chown ${toString zrok_uid}:${toString zrok_uid} /var/lib/zrok-frontend/identity.json
      fi
    '';
  };
}
