{ config, pkgs, lib, ... }:

with lib;

{
  options.server = {
    hostName = mkOption {
      type = types.str;
      default = "nixos";
      description = "The hostname of the server.";
    };
    publicDomain = mkOption {
      type = types.str;
      default = "example.com";
      description = "The primary public domain name for the server.";
    };
    privateDomain = mkOption {
      type = types.str;
      default = "local";
      description = "The internal domain name for the local network (e.g. skylab.local).";
    };
    adminEmail = mkOption {
      type = types.str;
      default = "admin@example.com";
      description = "The administrator email address.";
    };
    mainUser = mkOption {
      type = types.str;
      default = "master";
      description = "The primary administrator username.";
    };
    timezone = mkOption {
      type = types.str;
      default = "Europe/Paris";
      description = "The system timezone.";
    };
    locale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      description = "The system locale.";
    };
  };
}
