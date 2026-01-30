{ config, pkgs, ... }:

{
  # Redis Global Service
  # Shared cache and session storage for SKYLAB services.
  # Configured to use a Unix socket for improved performance and security.
  services.redis.servers."" = {
    enable = true;
    unixSocket = "/run/redis/redis.sock";
    unixSocketPerm = 660;
  };
}
