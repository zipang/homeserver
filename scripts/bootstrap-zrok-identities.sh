#!/usr/bin/env bash

# scripts/bootstrap-zrok-identities.sh
# One-time script to sync Ziti admin password and generate zrok-frontend identity.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== ZROK Identity Bootstrap ===${NC}"

# 1. Check if ziti-controller is running
if ! sudo podman ps | grep -q ziti-controller; then
    echo -e "${RED}ERROR: ziti-controller container is not running!${NC}"
    echo "Please start the service first: sudo systemctl start podman-ziti-controller.service"
    exit 1
fi

# 2. Get ZITI_PWD from secrets
CONTROLLER_ENV="/var/lib/secrets/zrok/controller.env"
if [ ! -f "$CONTROLLER_ENV" ]; then
    echo -e "${RED}ERROR: $CONTROLLER_ENV not found!${NC}"
    exit 1
fi

ZITI_PWD=$(sudo grep ZITI_PWD "$CONTROLLER_ENV" | cut -d= -f2)

if [ -z "$ZITI_PWD" ]; then
    echo -e "${RED}ERROR: ZITI_PWD not found in $CONTROLLER_ENV!${NC}"
    exit 1
fi

# 3. Synchronize admin password in Ziti database
echo -e "${YELLOW}[INFO]${NC} Synchronizing Ziti admin password..."
# Note: We try to login first, if it fails, we assume it's because of the password mismatch
if ! sudo podman exec ziti-controller ziti edge login localhost:1280 -u admin -p "$ZITI_PWD" -y > /dev/null 2>&1; then
    echo "  Login failed with current ZITI_PWD. Attempting to reset admin password..."
    # We use a trick: the quickstart sets a random password, but we can update it if we have access to the container
    # Since we are root on the host and have podman access, we can run ziti commands internally.
    # We'll use the 'ziti edge update authenticator' if we can find the current random password, 
    # OR we just force a reset if the CLI allows it without old password (unlikely for edge).
    # BETTER: The quickstart writes the password to /persistent/.env or console logs.
    
    echo "  Searching for auto-generated password..."
    AUTO_PWD=$(sudo podman exec ziti-controller cat /persistent/.env 2>/dev/null | grep ZITI_PWD | cut -d= -f2 || true)
    
    if [ -n "$AUTO_PWD" ]; then
        echo "  Found auto-generated password. Updating to match controller.env..."
        sudo podman exec ziti-controller ziti edge login localhost:1280 -u admin -p "$AUTO_PWD" -y
        sudo podman exec ziti-controller ziti edge update authenticator updb admin --password "$ZITI_PWD"
    else
        echo -e "${RED}  ERROR: Could not find auto-generated password to perform reset.${NC}"
        echo "  You may need to manually find the password in 'journalctl -u podman-ziti-controller' and run:"
        echo "  sudo podman exec -it ziti-controller ziti edge login localhost:1280 -u admin -p <OLD_PWD> -y"
        echo "  sudo podman exec -it ziti-controller ziti edge update authenticator updb admin --password $ZITI_PWD"
        exit 1
    fi
fi

echo -e "${GREEN}[SUCCESS]${NC} Ziti admin password is synchronized."

# 4. Create and Enroll zrok-frontend Identity
FRONTEND_IDENTITY="/var/lib/zrok-frontend/identity.json"

if [ -f "$FRONTEND_IDENTITY" ]; then
    echo -e "${YELLOW}[UNCHANGED]${NC} Identity already exists: $FRONTEND_IDENTITY"
else
    echo -e "${YELLOW}[INFO]${NC} Creating zrok-frontend identity..."
    sudo podman exec ziti-controller ziti edge create identity zrok-frontend -o /tmp/frontend.jwt
    echo -e "${YELLOW}[INFO]${NC} Enrolling zrok-frontend identity..."
    sudo podman exec ziti-controller ziti edge enroll --jwt /tmp/frontend.jwt --out /persistent/identity.json
    
    # Move to correct location and set permissions
    sudo mv /var/lib/ziti/identity.json "$FRONTEND_IDENTITY"
    sudo chown 2171:2171 "$FRONTEND_IDENTITY"
    sudo chmod 600 "$FRONTEND_IDENTITY"
    echo -e "${GREEN}[CREATED]${NC} $FRONTEND_IDENTITY"
fi

echo -e "\n${GREEN}=== Bootstrap Complete ===${NC}"
echo "You can now start the zrok services:"
echo "  sudo systemctl start podman-zrok-controller.service"
echo "  sudo systemctl start podman-zrok-frontend.service"
