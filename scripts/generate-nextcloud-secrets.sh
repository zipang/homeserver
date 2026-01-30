#!/usr/bin/env bash

# generate-nextcloud-secrets.sh
# Generates Nextcloud secrets only if they don't already exist.
# Should be run with sudo.

SECRETS_DIR="/var/lib/secrets/nextcloud"
NEXTCLOUD_USER="nextcloud"
NEXTCLOUD_GROUP="nextcloud"

# Ensure directory exists with correct permissions
if [ ! -d "$SECRETS_DIR" ]; then
    echo "Creating directory $SECRETS_DIR..."
    mkdir -p "$SECRETS_DIR"
    chown "$NEXTCLOUD_USER:$NEXTCLOUD_GROUP" "$SECRETS_DIR"
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
        openssl rand -base64 "$LENGTH" > "$FILE"
        chown "$NEXTCLOUD_USER:$NEXTCLOUD_GROUP" "$FILE"
        chmod 600 "$FILE"
    fi
}

# 1. admin_password
generate_secret "admin_password" 24

# 2. db_password
generate_secret "db_password" 24

echo "-------------------------------------------------------"
echo "Nextcloud secrets are ready in $SECRETS_DIR"
echo "-------------------------------------------------------"
echo "⚠️  IMPORTANT: You must manually set the PostgreSQL password for the 'nextcloud' user"
echo "   if it's the first time you're setting up the database."
echo "   Run: sudo -u postgres psql -c \"ALTER USER nextcloud WITH PASSWORD '$(cat $SECRETS_DIR/db_password)';\""
echo "-------------------------------------------------------"
