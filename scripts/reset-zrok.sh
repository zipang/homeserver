#!/usr/bin/env bash

# scripts/reset-zrok.sh
# Safely stops all zrok/ziti services and wipes their state for a fresh start.
# This does NOT delete your secrets in /var/lib/secrets/zrok/.

set -e

# Define services
SERVICES=(
    "podman-zrok-frontend.service"
    "zrok-bootstrap.service"
    "podman-zrok-controller.service"
    "podman-ziti-controller.service"
    "zrok-init.service"
    "zrok-network.service"
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
        sudo find "$dir" -mindepth 1 -delete
    fi
done

echo "--------------------------------------------------------"
echo "Reset complete. Automation is taking over."
echo "Starting services in sequence..."
echo "--------------------------------------------------------"

sudo systemctl start zrok-network.service
sudo systemctl start zrok-init.service
sudo systemctl start podman-ziti-controller.service
sudo systemctl start podman-zrok-controller.service
sudo systemctl start zrok-bootstrap.service
sudo systemctl start podman-zrok-frontend.service

echo ""
echo "Stack is starting. Monitor the bootstrap process with:"
echo "  journalctl -u zrok-bootstrap.service -f"
echo "--------------------------------------------------------"
