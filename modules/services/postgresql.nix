{ config, pkgs, ... }:

{
  # PostgreSQL Global Service
  # This instance is shared by multiple services (Authelia, Nextcloud, Immich, etc.)
  # Authentication is handled via Unix sockets (Peer Authentication) for local services.
  # 
  # We explicitly pin PostgreSQL 16 to move beyond the NixOS 24.05 default (v15).
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
  };
}
