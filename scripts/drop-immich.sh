#!/usr/bin/env bash

# Safety check: must run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

echo "--- Starting Immich Cleanup ---"

# 1. Stop services
echo "Stopping Immich services..."
systemctl stop immich-server.service immich-microservices.service immich-machine-learning.service redis-immich.service 2>/dev/null || true

# 2. Wipe data directories
echo "Removing data directories /var/lib/immich and /var/lib/redis-immich..."
rm -rf /var/lib/immich
rm -rf /var/lib/redis-immich

# 3. Drop PostgreSQL Database and User
echo "Dropping Immich database and user from PostgreSQL..."
# We use -u postgres to run psql commands
sudo -u postgres psql -c "DROP DATABASE IF EXISTS immich;"
sudo -u postgres psql -c "DROP USER IF EXISTS immich;"

echo "--- Cleanup Complete ---"
echo "You can now re-enable the Immich module and run 'nixos-rebuild switch'."
