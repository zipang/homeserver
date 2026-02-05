{ config, pkgs, ... }:

let
  domain = config.skylab.domain;
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = config.skylab.adminEmail;
    
    # We use Cloudflare DNS-01 challenge for the public domain
    # This allows us to get certificates without opening port 80/443
    certs."${domain}" = {
      inherit domain;
      extraDomainNames = [ "*.${domain}" ];
      dnsProvider = "cloudflare";

      # The token will be provided via sops-nix in /run/secrets/cloudflare_token
      credentialsFile = config.sops.secrets."acme/cloudflare_token".path;
      group = "nginx";
    };
  };

  # Ensure the directory for ACME challenges exists (though DNS-01 doesn't use it, ACME module might expect it)
  # and that the acme user can read the secrets
  users.users.acme.extraGroups = [ "nginx" ];
}
