# Fail2Ban Security

Fail2Ban is used to protect the server from brute-force attacks and malicious scanning by automatically banning IP addresses that show suspicious behavior.

## Configuration Reference

The complete list of available options for the `services.fail2ban` module can be found in the [official NixOS Service Search](https://search.nixos.org/options?channel=25.11&query=services.fail2ban).

## Full Configuration Template

The configuration is centralized in `modules/services/fail2ban.nix`:

```nix
{ config, pkgs, ... }: {
  services.fail2ban = {
    enable = true;
    
    # Global settings
    maxretry = 5;
    bantime = "-1"; # Permanent ban (requires manual unban)
    
    # Do not ban our local network
    ignoreIP = [
      "127.0.0.1/8"
      "192.168.1.0/24" # Local network range (see Nginx doc for explanation)
    ];

    # Jails for specific services
    jails = {
      # SSH protection
      sshd.settings = {
        enabled = true;
        maxretry = 3;
      };

      # Nginx protections
      nginx-http-auth.settings.enabled = true;
      nginx-botsearch.settings = {
        enabled = true;
        maxretry = 2;
      };
      nginx-bad-request.settings.enabled = true;
    };
  };
}
```

## Operational Guides

### Checking Banned IPs
To see which IPs are currently banned for a specific jail (e.g., `sshd`):
```bash
sudo fail2ban-client status sshd
```

To see all active jails and a summary:
```bash
sudo fail2ban-client status
```

### Unbanning an IP
If you accidentally ban yourself or a legitimate user:
```bash
sudo fail2ban-client unban <IP_ADDRESS>
```

To unban from a specific jail:
```bash
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

## Headless Operations & Troubleshooting

### View Service Logs
Monitor Fail2Ban actions and detections:
```bash
journalctl -u fail2ban.service -f
```

### Check Log File Directly
```bash
sudo tail -f /var/log/fail2ban.log
```

### Service Status
```bash
systemctl status fail2ban.service
```

### Common Issues
- **Permanent Bans**: Since `bantime` is set to `-1`, bans will persist across reboots. Use `fail2ban-client unban` to clear them manually.
- **Ignored IPs**: If you cannot ban an IP, verify it isn't listed in the `ignoreIP` list in `modules/services/fail2ban.nix`.
