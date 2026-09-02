{ config, pkgs, ... }:

{
  # Redis Global Service
  # Shared cache and session storage for SKYLAB services.
  # Configured to use a Unix socket for improved performance and security.
  #
  # Note: in nixpkgs 25.11, `package` is a shared option (all instances use
  # the same redis package), and `services.redis.enable` is a deprecated
  # alias - instances are enabled under services.redis.servers.<name>.
  services.redis = {
    package = pkgs.redis; # Force use of standard Redis to avoid Valkey build issues
    servers."" = {
      enable = true;
      unixSocket = "/run/redis/redis.sock";
      unixSocketPerm = 660;
    };
  };
}
