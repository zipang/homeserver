#!/usr/bin/env bash

# scripts/reset-zrok.sh
# Safely stops all zrok/ziti services and wipes their state for a fresh start.
# This does NOT delete your secrets in /var/lib/secrets/zrok/.

set -e

# Define services
SERVICES=(
    "podman-zrok-frontend.service"
    "podman-zrok-controller.service"
    "podman-ziti-controller.service"
    "zrok-init.service"
)

# Define data directories
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
        # We use find to delete contents but keep the directory itself to preserve permissions
        sudo find "$dir" -mindepth 1 -delete
    fi
done

echo "--------------------------------------------------------"
echo "Reset complete. To restart the stack:"
echo "  1. sudo systemctl start zrok-init.service"
echo "  2. sudo systemctl start podman-ziti-controller.service"
echo "  3. (Wait 15s) sudo systemctl start podman-zrok-controller.service"
echo "  4. sudo systemctl start podman-zrok-frontend.service"
echo "--------------------------------------------------------"
echo "Monitor logs with: journalctl -u podman-zrok-controller.service -f"
