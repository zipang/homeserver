#!/usr/bin/env bash

# generate-zrok-setup.sh
# Unified script to generate zrok secrets and configuration files
# This script is idempotent - it can be run multiple times safely

set -e

SECRETS_DIR="/var/lib/secrets/zrok"
CONTROLLER_ENV="$SECRETS_DIR/controller.env"
FRONTEND_ENV="$SECRETS_DIR/frontend.env"
CONTROLLER_CONFIG="/var/lib/zrok-controller/config.yml"
FRONTEND_CONFIG="/var/lib/zrok-frontend/config.yml"

# Get DNS Zone from environment or prompt
if [ -z "$ZROK_DNS_ZONE" ]; then
    read -p "Enter your DNS zone (e.g., example.com): " ZROK_DNS_ZONE
fi

if [ -z "$ZROK_DNS_ZONE" ]; then
    echo "Error: ZROK_DNS_ZONE is required."
    exit 1
fi

ZITI_CTRL_PORT=1280
ZROK_CTRL_PORT=18080

# Arrays to track what we did
CREATED_FILES=()
UNCHANGED_FILES=()
MODIFIED_FILES=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== ZROK Setup Script ==="
echo "This script will generate secrets and configuration files for zrok."
echo ""

# Helper to generate random strings
gen_secret() {
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"
}

# Helper to create file with ownership and permissions
create_file() {
    local file="$1"
    local content="$2"
    local permissions="${3:-600}"
    local owner="${4:-zrok:zrok}"

    if [ -f "$file" ]; then
        echo -e "${YELLOW}[UNCHANGED]${NC} $file"
        UNCHANGED_FILES+=("$file")
    else
        echo "$content" > "$file"
        chmod "$permissions" "$file"
        chown "$owner" "$file"
        echo -e "${GREEN}[CREATED]${NC} $file"
        CREATED_FILES+=("$file")
    fi
}

# Helper to update file if content differs
update_file_if_changed() {
    local file="$1"
    local content="$2"
    local permissions="${3:-600}"
    local owner="${4:-zrok:zrok}"

    if [ ! -f "$file" ]; then
        echo "$content" > "$file"
        chmod "$permissions" "$file"
        chown "$owner" "$file"
        echo -e "${GREEN}[CREATED]${NC} $file"
        CREATED_FILES+=("$file")
    else
        local current_content
        current_content=$(cat "$file")
        if [ "$current_content" != "$content" ]; then
            echo "$content" > "$file"
            chmod "$permissions" "$file"
            chown "$owner" "$file"
            echo -e "${YELLOW}[UPDATED]${NC} $file"
            MODIFIED_FILES+=("$file")
        else
            echo -e "${YELLOW}[UNCHANGED]${NC} $file"
            UNCHANGED_FILES+=("$file")
        fi
    fi
}

# Ensure directories exist with correct ownership
echo -e "\n${YELLOW}[INFO]${NC} Setting up directories..."

for dir in "$SECRETS_DIR" "/var/lib/zrok-controller" "/var/lib/zrok-frontend"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        chmod 755 "$dir"
        chown zrok:zrok "$dir"
        echo -e "${GREEN}[CREATED]${NC} Directory: $dir"
    else
        chown zrok:zrok "$dir"
        chmod 755 "$dir"
        echo -e "${YELLOW}[UNCHANGED]${NC} Directory: $dir"
    fi
done

# Generate controller.env
echo -e "\n${YELLOW}[INFO]${NC} Generating secrets..."
if [ ! -f "$CONTROLLER_ENV" ]; then
    ZROK_ADMIN_TOKEN=$(gen_secret 32)
    ZITI_PWD=$(gen_secret 24)
    content="ZROK_ADMIN_TOKEN=$ZROK_ADMIN_TOKEN
ZITI_PWD=$ZITI_PWD"
    create_file "$CONTROLLER_ENV" "$content"
else
    echo -e "${YELLOW}[UNCHANGED]${NC} $CONTROLLER_ENV"
    UNCHANGED_FILES+=("$CONTROLLER_ENV")
fi

# Read existing secrets
[ -f "$CONTROLLER_ENV" ] && source "$CONTROLLER_ENV"

# Generate frontend.env
if [ ! -f "$FRONTEND_ENV" ]; then
    ZROK_OAUTH_HASH_KEY=$(gen_secret 32)
    content="# Google OAuth Credentials (Required for SSO)
ZROK_OAUTH_GOOGLE_CLIENT_ID=REPLACE_ME_WITH_GOOGLE_CLIENT_ID
ZROK_OAUTH_GOOGLE_CLIENT_SECRET=REPLACE_ME_WITH_GOOGLE_CLIENT_SECRET

# 32-character random string for signing/encrypting OAuth cookies
ZROK_OAUTH_HASH_KEY=$ZROK_OAUTH_HASH_KEY"
    create_file "$FRONTEND_ENV" "$content"
else
    [ -f "$FRONTEND_ENV" ] && source "$FRONTEND_ENV"
    echo -e "${YELLOW}[UNCHANGED]${NC} $FRONTEND_ENV"
    UNCHANGED_FILES+=("$FRONTEND_ENV")
fi

# Ensure secret files have correct permissions
chmod 600 "$SECRETS_DIR"/*.env
chown zrok:zrok "$SECRETS_DIR"/*.env

# Generate zrok-controller config.yml
echo -e "\n${YELLOW}[INFO]${NC} Generating configuration files..."
if [ -z "$ZROK_ADMIN_TOKEN" ] || [ -z "$ZITI_PWD" ]; then
    echo -e "${RED}[ERROR]${NC} Required secrets not found! Please ensure $CONTROLLER_ENV exists and contains ZROK_ADMIN_TOKEN and ZITI_PWD."
    exit 1
fi

controller_config="v: 4
admin:
  secrets: [\"$ZROK_ADMIN_TOKEN\"]
endpoint:
  host: 0.0.0.0
  port: ${ZROK_CTRL_PORT}
store:
  path: /var/lib/zrok-controller/sqlite3.db
  type: sqlite3
ziti:
  api_endpoint: https://ziti-controller:${ZITI_CTRL_PORT}/edge/management/v1
  username: admin
  password: \"$ZITI_PWD\""

update_file_if_changed "$CONTROLLER_CONFIG" "$controller_config" 600 "zrok:zrok"

# Generate zrok-frontend config.yml
frontend_config="v: 4
host_match: ${ZROK_DNS_ZONE}
address: 0.0.0.0:8080
ziti_identity: \"/var/lib/zrok-frontend/identity.json\"
ziti:
  api_endpoint: https://ziti-controller:${ZITI_CTRL_PORT}/edge/management/v1
  username: admin
  password: \"${ZITI_PWD:-}\"
oauth:
  bind_address: 0.0.0.0:8081
  endpoint_url: https://oauth.${ZROK_DNS_ZONE}
  cookie_domain: ${ZROK_DNS_ZONE}
  signing_key: \"${ZROK_OAUTH_HASH_KEY:-placeholder_32_chars_long_key_0123}\"
  encryption_key: \"${ZROK_OAUTH_HASH_KEY:-placeholder_32_chars_long_key_0123}\"
  providers:
    - name: google
      type: google
      client_id: \"${ZROK_OAUTH_GOOGLE_CLIENT_ID:-placeholder}\"
      client_secret: \"${ZROK_OAUTH_GOOGLE_CLIENT_SECRET:-placeholder}\""

update_file_if_changed "$FRONTEND_CONFIG" "$frontend_config" 600 "zrok:zrok"

# Summary
echo ""
echo "=== Summary ==="
echo -e "${GREEN}Created files: ${#CREATED_FILES[@]}${NC}"
for file in "${CREATED_FILES[@]}"; do
    echo "  - $file"
done

if [ ${#MODIFIED_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Modified files: ${#MODIFIED_FILES[@]}${NC}"
    for file in "${MODIFIED_FILES[@]}"; do
        echo "  - $file"
    done
fi

echo -e "${YELLOW}Unchanged files: ${#UNCHANGED_FILES[@]}${NC}"
for file in "${UNCHANGED_FILES[@]}"; do
    echo "  - $file"
done

echo ""
echo -e "${GREEN}=== Setup Complete ===${NC}"
echo "All secrets and configuration files are ready."
echo ""
echo "If you haven't done so already, edit $FRONTEND_ENV to add your Google OAuth credentials:"
echo "  ZROK_OAUTH_GOOGLE_CLIENT_ID"
echo "  ZROK_OAUTH_GOOGLE_CLIENT_SECRET"