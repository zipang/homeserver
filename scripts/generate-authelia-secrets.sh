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

echo "-------------------------------------------------------"
echo "Initializing users.yml..."
echo "-------------------------------------------------------"

STATE_DIR="/var/lib/authelia-main"
USERS_FILE="$STATE_DIR/users.yml"

if [ -f "$USERS_FILE" ] && [ -s "$USERS_FILE" ] && [ "$(cat "$USERS_FILE")" != "users:" ]; then
    echo "✅ $USERS_FILE already exists and is not empty. Skipping."
else
    echo "👤 Setting up the initial administrator user..."
    read -p "Enter admin username (e.g. zipang): " ADMIN_USER
    read -p "Enter admin email: " ADMIN_EMAIL
    
    # Generate a strong random password for the user
    ADMIN_PASSWORD=$(openssl rand -base64 24)
    
    echo "✨ User database initialized."
    echo "⚠️  IMPORTANT: The password for '$ADMIN_USER' is: $ADMIN_PASSWORD"
    echo "   Authelia expects a HASHED password in users.yml."
    
    # Generate hash using Nix
    echo "🔑 Hashing password using 'nix run nixpkgs#authelia' (this may take a moment)..."
    HASHED_PASSWORD=$(nix run nixpkgs#authelia -- hash-password "$ADMIN_PASSWORD" | awk '{print $3}')
    
    if [ -z "$HASHED_PASSWORD" ] || [[ ! "$HASHED_PASSWORD" =~ ^\$argon2id ]]; then
        echo "❌ Failed to generate hash automatically."
        echo "   Please run: 'nix run nixpkgs#authelia -- hash-password $ADMIN_PASSWORD'"
        echo "   and replace the plain text password in $USERS_FILE."
        HASHED_PASSWORD="<REPLACE_WITH_HASH_OF_$ADMIN_PASSWORD>"
    fi
    
    cat <<EOF > "$USERS_FILE"
users:
  $ADMIN_USER:
    displayname: "$ADMIN_USER"
    password: "$HASHED_PASSWORD"
    email: $ADMIN_EMAIL
    groups:
      - admins
EOF
    chown "$AUTHELIA_USER:$AUTHELIA_GROUP" "$USERS_FILE"
    chmod 600 "$USERS_FILE"
    
    echo "✅ /var/lib/authelia-main/users.yml created."
fi

echo "Done. All secrets and user database are ready."
