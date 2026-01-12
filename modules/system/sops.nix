{ config, pkgs, ... }:

{
  # sops-nix configuration
  sops = {
    # This will use the host's SSH key for decryption
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    
    # Default format for the files
    defaultSopsFormat = "binary";

    # Secrets definition
    # Example usage in other modules:
    # systemd.services.jellyfin.serviceConfig.EnvironmentFile = config.sops.secrets."jellyfin.env".path;
    secrets = {
      # Placeholder for initial setup
      "test.env" = {
        owner = "master";
        path = "/run/secrets/test.env";
        sopsFile = ../../secrets/test.env;
        format = "binary";
      };
    };
  };
}
