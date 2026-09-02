{ config, pkgs, ... }:

{
  # Redis Global Service
  # Shared cache and session storage for SKYLAB services.
  # Configured to use a Unix socket for improved performance and security.
  #
  # Note: since nixpkgs 24.05+, the multi-instance form services.redis.servers
  # is the canonical option tree; the legacy services.redis.* aliases are
  # deprecated and emit an evaluation warning.
  services.redis.servers."" = {
    enable = true;
    package = pkgs.redis; # Force use of standard Redis to avoid Valkey build issues
    unixSocket = "/run/redis/redis.sock";
    unixSocketPerm = 660;
  };
}
