{ config, pkgs, ... }:

{
  # sops-nix configuration
  sops = {
    # This will use the host's SSH key for decryption
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    
    # Default format for the files
    defaultSopsFormat = "binary";

    # Secrets definition
    secrets = {
      # "authelia/env" = {
      #   sopsFile = "/var/lib/secrets/sso/authelia.env";
      #   format = "dotenv";
      #   owner = "authelia-main";
      # };
      "acme/cloudflare_token" = {
        owner = "acme";
        group = "acme";
      };
    };
  };
}
