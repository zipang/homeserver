{ config, pkgs, lib, ... }:

let
  zrok_dns_zone = "skylab.quest";
  ziti_ctrl_port = 1280;
  zrok_ctrl_port = 18080;
in
{
  # zrok Infrastructure & Homepage
  # This module implements a self-hosted zrok instance using OCI containers.

  virtualisation.oci-containers.containers = {
    # 1. OpenZiti Controller & Router (Quickstart)
    ziti-controller = {
      image = "openziti/ziti-cli:latest";
      environment = {
        ZITI_CTRL_ADVERTISED_ADDRESS = "ziti.${zrok_dns_zone}";
        ZITI_CTRL_ADVERTISED_PORT = "${toString ziti_ctrl_port}";
      };
      volumes = [ "/var/lib/ziti:/persistent" ];
      cmd = [ "edge", "quickstart", "controller" ];
      ports = [ 
        "${toString ziti_ctrl_port}:${toString ziti_ctrl_port}"
        "10080:10080" # Edge API
      ];
    };

    # 2. zrok Controller
    zrok-controller = {
      image = "openziti/zrok:latest";
      dependsOn = [ "ziti-controller" ];
      environmentFiles = [ "/var/lib/secrets/zrok/controller.env" ];
      volumes = [
        "/var/lib/zrok-controller:/var/lib/zrok-controller"
        "/var/lib/ziti:/persistent" 
      ];
      cmd = [ "controller", "/var/lib/zrok-controller/config.yml" ];
    };

    # 3. zrok Frontend (Public Access & OAuth)
    zrok-frontend = {
      image = "openziti/zrok:latest";
      dependsOn = [ "zrok-controller" ];
      ports = [
        "80:8080"
        "443:8080"
      ];
      environmentFiles = [ "/var/lib/secrets/zrok/frontend.env" ];
      volumes = [ "/var/lib/zrok-frontend:/var/lib/zrok-frontend" ];
      cmd = [ "access", "public", "/var/lib/zrok-frontend/config.yml" ];
    };

    # 4. Static Homepage (Nginx)
    homepage = {
      image = "nginx:alpine";
      volumes = [ "/var/www/homepage:/usr/share/nginx/html:ro" ];
      # Only accessible locally, zrok will proxy to it
      ports = [ "127.0.0.1:8000:80" ];
    };
  };

  # Configuration Generator
  # Generates YAML configs from environment variables before containers start
  systemd.services.zrok-init = {
    description = "Initialize zrok and Ziti configuration files";
    wantedBy = [ "multi-user.target" ];
    before = [ "docker-ziti-controller.service" "docker-zrok-controller.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # 1. Ensure directories exist
      mkdir -p /var/lib/ziti /var/lib/zrok-controller /var/lib/zrok-frontend /var/www/homepage

      # 2. Generate Homepage index.html
      cat <<EOF > /var/www/homepage/index.html
<!DOCTYPE html>
<html>
<head><title>SKYLAB HOMELAB</title></head>
<body style="background-color: #121212; color: #ffffff; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;">
    <h1>SKYLAB HOMELAB</h1>
</body>
</html>
EOF

      # 3. Load Secrets for Config Generation
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
      
      chown -R root:root /var/lib/ziti /var/lib/zrok-controller /var/lib/zrok-frontend
      chmod 600 /var/lib/zrok-controller/config.yml /var/lib/zrok-frontend/config.yml
    '';
  };

  # Storage and Firewall
  systemd.tmpfiles.rules = [
    "d /var/lib/secrets/zrok 0700 root root -"
    "d /var/lib/ziti 0700 root root -"
    "d /var/lib/zrok-controller 0700 root root -"
    "d /var/lib/zrok-frontend 0700 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ziti_ctrl_port 10080 ];
}
