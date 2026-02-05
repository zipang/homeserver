{ config, pkgs, lib, ... }:

with lib;

{
  options.skylab = {
    domain = mkOption {
      type = types.str;
      default = "example.com";
      description = "The primary domain name for the SKYLAB server.";
    };
    adminEmail = mkOption {
      type = types.str;
      default = "admin@example.com";
      description = "The administrator email address.";
    };
  };
}
