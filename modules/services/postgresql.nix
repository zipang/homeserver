{ config, pkgs, ... }:

{
  # PostgreSQL Global Service
  # This instance is shared by multiple services (Authelia, Nextcloud, etc.)
  # Authentication is handled via Unix sockets (Peer Authentication) for local services.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
  };
}
