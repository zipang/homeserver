{ config, pkgs, lib, ... }:

with lib;

{
  options.server = {
    hostName = mkOption {
      type = types.str;
      description = "The hostname of the server.";
    };
    publicDomain = mkOption {
      type = types.str;
      description = "The primary public domain name for the server.";
    };
    privateDomain = mkOption {
      type = types.str;
      description = "The internal domain name for the server on the local network (e.g. myserver.local).";
    };
    adminEmail = mkOption {
      type = types.str;
      description = "The administrator email address.";
    };
    mainUser = mkOption {
      type = types.str;
      description = "The primary administrator username.";
    };
    timezone = mkOption {
      type = types.str;
      description = "The system timezone.";
    };
    locale = mkOption {
      type = types.str;
      description = "The system locale.";
    };
  };
}
