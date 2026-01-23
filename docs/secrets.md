# Secrets Management

To securely store and manage sensitive information (like API tokens, passwords, and private keys) within our public Git repository. We use `sops` (Secrets OPerationS) with `age` encryption to ensure that secrets are only accessible by the server and authorized administrators.
The configuration for `sops-nix` is defined in `modules/system/sops.nix`:

## Configuration Reference

For the full list of options, refer to the [sops-nix official documentation](https://github.com/Mic92/sops-nix).

## Full Configuration Template

```nix
{ config, pkgs, ... }: {
  sops = {
    # This will use the host's SSH key for decryption
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    
    # Default format for the files
    defaultSopsFormat = "binary";

    # Secrets definition
    secrets = {
      "jellyfin.env" = {
        sopsFile = ../../secrets/jellyfin.env;
        format = "binary";
      };
      # Add more secrets here...
    };
  };
}
```

## TLDR; How it works

1.  **Encryption**: Secrets are stored as binary blobs in the `secrets/` directory.
2.  **Access**:
    *   **Admins**: Use a private `age` key on their local machine to edit/view secrets.
    *   **Server**: Uses its own SSH host key (`/etc/ssh/ssh_host_ed25519_key`) to decrypt secrets at runtime.
3.  **Create/Update a secret**: Create a file (e.g., `secrets/service.env`) with your secrets.
4.  **Encrypt**: Run the management script to encrypt it in-place:
    ```bash
    ./scripts/secrets encrypt secrets/service.env
    ```
5.  **Configure**: Add the secret to `modules/system/sops.nix`.
6.  **Use**: Reference the secret in your service configuration:
## Headless Operations & Troubleshooting

If a service fails to find its secrets, use these commands to debug:

### Verify Secret Files
NixOS decrypts secrets into `/run/secrets/`. Check if they exist:
```bash
ls -la /run/secrets
```

### Check Secret Content (Root Only)
Verify the decrypted content matches your expectation:
```bash
sudo cat /run/secrets/jellyfin.env
```

### Verify Service Integration
Check if a specific systemd service is correctly linked to its `EnvironmentFile`:
```bash
systemctl show jellyfin.service -p EnvironmentFile
```

### Logs
Check `sops-nix` initialization logs:
```bash
journalctl -t sops-nix
```

## Setup Instructions

You must have an `age` key to encrypt/decrypt secrets. The public key must be added to `.sops.yaml`.
The server uses its SSH host key (`/etc/ssh/ssh_host_ed25519_key`) for decryption.

### 1. Generate your Admin Key
If you don't have an `age` key yet, generate one on your local machine:
```bash
nix-shell -p age --run "age-keygen -o ~/.config/sops/age/keys.txt"
```
Then, extract your public key:
```bash
cat ~/.config/sops/age/keys.txt | grep "public key"
```

### 2. Configure SOPS
Add your public key to the `.sops.yaml` file in the repository root:
```yaml
creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env|ini)$
    # ...
    key_groups:
      - age:
        - "age1your_public_key_here" # Your Admin Key
        - "age1server_public_key_here" # Server SSH-to-age Key
```

### 3. Get the Server's Public Key
To allow the server to decrypt the secrets, you need its `age` equivalent of the SSH host key. Run this on the server:
```bash
nix-shell -p ssh-to-age --run "ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub"
```
Add the output to `.sops.yaml`.

## Usage Example

### 1. Create a secret file
Create a standard environment file (e.g., `secrets/jellyfin.env`):
```env
JELLYFIN_API_KEY=my_secret_token
```

### 2. Encrypt the file

Use the `secrets` management script provided in the repository:
```bash
./scripts/secrets encrypt secrets/jellyfin.env
```
The file is now an encrypted binary blob. You can safely commit it to Git.

The `./scripts/secrets` script simplifies common tasks like:
*   `./scripts/secrets encrypt <file>`: Encrypt a new or updated file in-place.
*   `./scripts/secrets edit <file>`: Open an encrypted file in your `$EDITOR`. Re-encrypts automatically on save.
*   `./scripts/secrets decrypt <file>`: View the decrypted content in the terminal.

### 3. Use in NixOS
Declare the secret in your module (e.g., `modules/services/jellyfin.nix`):
```nix
{ config, ... }:
{
  sops.secrets."jellyfin.env" = {
    sopsFile = ../../secrets/jellyfin.env;
    format = "binary";
  };

  systemd.services.jellyfin.serviceConfig.EnvironmentFile = config.sops.secrets."jellyfin.env".path;
}
```
