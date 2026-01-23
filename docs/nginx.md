# Nginx Reverse Proxy

Nginx acts as the primary traffic manager for SKYLAB, allowing us to access internal services via user-friendly domain names (e.g., `syncthing.skylab.local`) instead of IP addresses and port numbers.

## Configuration Reference

The complete list of available options for the `services.nginx` module can be found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.nginx) (targeting the current NixOS version, e.g., 25.11).

## Full Configuration Template

You can use this template in `modules/services/nginx.nix` to configure the service:

```nix
{ config, pkgs, ... }: {
  services.nginx = {
    enable = true;
    
    # Optimizations for a home server
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    # Default client_max_body_size (useful for file uploads)
    clientMaxBodySize = "10G";

    # Virtual Hosts
    virtualHosts."syncthing.skylab.local" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8384";
        proxyWebsockets = true;
      };
    };
  };

  # Firewall rules for HTTP and HTTPS
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
```

## Local Domain Resolution

Since we are using custom `.local` subdomains, they will not resolve automatically via mDNS/Avahi. You must manually add them to your client machine's hosts file.

### On Linux or macOS
Edit `/etc/hosts`:
```text
<SKYLAB_IP> syncthing.skylab.local
```

### On Windows
Edit `C:\Windows\System32\drivers\etc\hosts`:
```text
<SKYLAB_IP> syncthing.skylab.local
```

## Headless Operations & Troubleshooting

### View Service Logs
Check Nginx logs for connection errors or configuration issues:
```bash
journalctl -u nginx.service -f
```

### Configuration Check
Test the Nginx configuration for syntax errors without restarting the service:
```bash
sudo nginx -t
```

### Service Status
```bash
systemctl status nginx.service
```

### Common Issues
- **502 Bad Gateway**: The target service (e.g., Syncthing) is not running or is not listening on the expected port/address.
- **403 Forbidden**: Check file permissions if Nginx is serving static files directly.
- **WebSocket connection failed**: Ensure `proxyWebsockets = true;` is set in the virtual host configuration.
