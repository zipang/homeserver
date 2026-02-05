#!/usr/bin/env bash

# scripts/reset-zrok.sh
# Safely stops all zrok/ziti services and wipes their state for a fresh start.

set -e

# Define services
SERVICES=(
    "zrok-network.service"
    "zrok-init.service"
    "podman-ziti-controller.service"
    "podman-zrok-frontend.service"
    "podman-zrok-controller.service"
)

# Define data directories (NOT including secrets - we keep those)
DATA_DIRS=(
    "/var/lib/ziti"
    "/var/lib/zrok-controller"
    "/var/lib/zrok-frontend"
)

echo "Stopping zrok and Ziti services..."
for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc"; then
        echo "  Stopping $svc..."
        sudo systemctl stop "$svc"
    fi
done

echo "Wiping persistent state (keeping secrets)..."
for dir in "${DATA_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  Clearing $dir..."
        sudo find "$dir" -mindepth 1 -delete
    fi
done

# Ensure permissions are reset immediately via tmpfiles
echo "  Applying tmpfiles rules..."
sudo systemd-tmpfiles --create /etc/tmpfiles.d/*.conf || true

echo "--------------------------------------------------------"
echo "Zrok configuration has been erased and the services stopped. "
echo "--------------------------------------------------------"
