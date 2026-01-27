#!/usr/bin/env bash

# Safety check: must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "--- Starting Immich Cleanup (ZFS & NixOS Aware) ---"

# 1. Stop services
echo "Stopping Immich services..."
systemctl stop immich-server.service immich-microservices.service immich-machine-learning.service redis-immich.service 2>/dev/null || true

# 2. Wipe data directories
echo "Handling data directories..."

# Handle /var/lib/immich (Check if it's a mount point)
if mountpoint -q /var/lib/immich; then
    echo "/var/lib/immich is a mount point (ZFS), clearing contents only..."
    # Clear contents including hidden files, but keep the mount point
    rm -rf /var/lib/immich/*
    find /var/lib/immich -mindepth 1 -maxdepth 1 -name ".*" -exec rm -rf {} + 2>/dev/null || true
else
    echo "/var/lib/immich is NOT a mount point, removing directory..."
    rm -rf /var/lib/immich
fi

# Always safe to remove redis data dir if it's not a mount
echo "Removing /var/lib/redis-immich..."
rm -rf /var/lib/redis-immich

# 3. Drop PostgreSQL Database and User
echo "Cleaning up PostgreSQL data..."
if getent passwd postgres > /dev/null; then
    echo "Postgres user exists, attempting to drop database via psql..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS immich;" 2>/dev/null || true
    sudo -u postgres psql -c "DROP USER IF EXISTS immich;" 2>/dev/null || true
else
    echo "Postgres user not found (service likely disabled via NixOS)."
    if [ -d "/var/lib/postgresql" ]; then
        echo "Wiping /var/lib/postgresql for a fresh start..."
        rm -rf /var/lib/postgresql
    fi
fi

echo "--- Cleanup Complete ---"
echo "You can now re-enable the Immich module in configuration.nix and run 'nixos-rebuild switch'."
