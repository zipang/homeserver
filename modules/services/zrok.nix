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

# Setup Validator
# Checks if zrok setup has been run and prevents container startup if not
systemd.services.zrok-init = {
  description = "Validate zrok setup before starting containers";
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
  };
  script = ''
    echo "Checking zrok setup..."

    # Check all required files exist
    required_files=(
      "/var/lib/secrets/zrok/controller.env"
      "/var/lib/secrets/zrok/frontend.env"
      "/var/lib/zrok-controller/config.yml"
      "/var/lib/zrok-frontend/config.yml"
    )

    missing_files=()
    for file in "''${required_files[@]}"; do
      if [ ! -f "$file" ]; then
        missing_files+=("$file")
      fi
    done

    if [ ''${#missing_files[@]} -gt 0 ]; then
      echo "ERROR: Required files are missing!"
      echo ""
      echo "The following files need to be created:"
      for file in "''${missing_files[@]}"; do
        echo "  - $file"
      done
      echo ""
      echo "Please run the setup script to generate all required files:"
      echo "  sudo /home/master/homeserver/scripts/generate-zrok-setup.sh"
      echo ""
      echo "Then start the zrok services again."
      exit 1
    fi

    echo "All required files found. zrok setup is valid."
  '';
};

  # Storage and Firewall
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/zrok 0755 ${toString zrok_uid} ${toString zrok_uid} -"
    "d /var/lib/ziti 0755 ${toString ziti_uid} ${toString ziti_uid} -"
    "d /var/lib/zrok-controller 0755 ${toString zrok_uid} ${toString zrok_uid} -"
    "d /var/lib/zrok-frontend 0755 ${toString ziti_uid} ${toString zrok_uid} -"
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
      TimeoutStartSec = "1min";
    };
    script = ''
      # We check if podman is actually responsive before trying
      until podman version >/dev/null 2>&1; do
        echo "Waiting for podman daemon..."
        sleep 2
      done
      podman network inspect zrok-net >/dev/null 2>&1 || podman network create zrok-net
    '';
  };

# Install zrok and ziti CLIs on the host for management
environment.systemPackages = [ pkgs.zrok pkgs.openziti ];

# Manual service control - no autostart allows manual systemctl start
# The following lines would enable automatic startup - commented out for manual control:

# # Uncomment these lines to enable automatic startup on boot:
# systemd.services."podman-ziti-controller".wantedBy = [ "multi-user.target" ];
# systemd.services."podman-zrok-controller".wantedBy = [ "multi-user.target" ];
# systemd.services."podman-zrok-frontend".wantedBy = [ "multi-user.target" ];

# Prevent restart loops until configuration is fixed
systemd.services."podman-ziti-controller".serviceConfig.Restart = lib.mkForce "no";
systemd.services."podman-zrok-controller".serviceConfig.Restart = lib.mkForce "no";
systemd.services."podman-zrok-frontend".serviceConfig.Restart = lib.mkForce "no";

# Service dependencies for ordering only (no autostart triggers)
# 'after': ordering - wait for services to complete startup
# Uncomment 'wants' lines below to enable autostart chains:

systemd.services."podman-ziti-controller" = {
  after = [ "zrok-init.service" "zrok-network.service" ];
  # wants = [ "zrok-init.service" "zrok-network.service" ];  # Commented to prevent autostart
};

systemd.services."podman-zrok-controller" = {
  after = [ "podman-ziti-controller.service" ];
};

systemd.services."podman-zrok-frontend" = {
  after = [ "podman-zrok-controller.service" ];
};
}
