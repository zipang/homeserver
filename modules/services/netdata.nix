{ config, pkgs, lib, ... }:

{
  nixpkgs.config.allowUnfree = true;

  services.netdata.package = pkgs.netdata.override {
    withCloudUi = true;
    # The NUC8i7HVK has no BMC/IPMI management controller. Building netdata
    # without its freeipmi plugin avoids journalctl spam ("internal error" +
    # kernel x86/PAT warnings) from sensor polling that can never succeed.
    withIpmi = false;
  };

  services.netdata = {
    enable = true;
    config = {
      global = {
        "memory mode" = "ram";
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };
    };
  };

  # Nginx Reverse Proxy (Private Domain with Local SSL)
  services.nginx.virtualHosts."monitor.${config.server.privateDomain}" = {
    forceSSL = true;
    sslCertificate = "/var/lib/secrets/certs/skylab.crt";
    sslCertificateKey = "/var/lib/secrets/certs/skylab.key";

    locations."/" = {
      proxyPass = "http://127.0.0.1:19999";
      proxyWebsockets = true;
    };
  };
}
