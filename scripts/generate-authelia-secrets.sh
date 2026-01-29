#!/usr/bin/env bash

# generate-authelia-secrets.sh
# Generates Authelia secrets only if they don't already exist.
# Should be run with sudo.

SECRETS_DIR="/var/lib/secrets/authelia"
AUTHELIA_USER="authelia-main"
AUTHELIA_GROUP="authelia-main"

# Ensure directory exists with correct permissions
if [ ! -d "$SECRETS_DIR" ]; then
    echo "Creating directory $SECRETS_DIR..."
    mkdir -p "$SECRETS_DIR"
    chown "$AUTHELIA_USER:$AUTHELIA_GROUP" "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
fi

generate_secret() {
    local NAME=$1
    local LENGTH=$2
    local FILE="$SECRETS_DIR/$NAME"

    if [ -f "$FILE" ]; then
        echo "✅ $NAME already exists. Skipping."
    else
        echo "🔑 Generating $NAME..."
        openssl rand -hex "$LENGTH" > "$FILE"
        chown "$AUTHELIA_USER:$AUTHELIA_GROUP" "$FILE"
        chmod 600 "$FILE"
    fi
}

# 1. JWT_SECRET (Recommended 64+ chars)
generate_secret "JWT_SECRET" 64

# 2. SESSION_SECRET (32 chars)
generate_secret "SESSION_SECRET" 32

# 3. STORAGE_ENCRYPTION_KEY (Min 20 chars, using 32)
generate_secret "STORAGE_ENCRYPTION_KEY" 32

# 4. STORAGE_PASSWORD (PostgreSQL user password)
generate_secret "STORAGE_PASSWORD" 32

echo "Done. All secrets are ready in $SECRETS_DIR."
