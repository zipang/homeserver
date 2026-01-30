#!/usr/bin/env bash

# generate-nextcloud-secrets.sh
# Generates Nextcloud secrets only if they don't already exist.
# Should be run with sudo.

SECRETS_DIR="/var/lib/secrets/nextcloud"
NEXTCLOUD_USER="nextcloud"
NEXTCLOUD_GROUP="nextcloud"

# 1. Ensure directory exists with correct permissions
if [ ! -d "$SECRETS_DIR" ]; then
    echo "Creating directory $SECRETS_DIR..."
    mkdir -p "$SECRETS_DIR"
    chown "$NEXTCLOUD_USER:$NEXTCLOUD_GROUP" "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"
fi

# 1b. Ensure main data directory structure and ownership (Fixes setup service failures)
echo "📂 Ensuring /var/lib/nextcloud structure and ownership..."
mkdir -p /var/lib/nextcloud/config /var/lib/nextcloud/data /var/lib/nextcloud/store-apps
chown -R "$NEXTCLOUD_USER:$NEXTCLOUD_GROUP" /var/lib/nextcloud
chmod 750 /var/lib/nextcloud

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

# 3. Automatically set PostgreSQL password
DB_PASS=$(cat "$SECRETS_DIR/db_password")
echo "🐘 Setting PostgreSQL password for 'nextcloud' user..."

# Ensure the role exists before trying to set the password
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='nextcloud'" | grep -q 1; then
    echo "🏗️  Role 'nextcloud' not found. Creating it..."
    sudo -u postgres psql -c "CREATE ROLE nextcloud WITH LOGIN;"
fi

if sudo -u postgres psql -c "ALTER USER nextcloud WITH PASSWORD '$DB_PASS';" > /dev/null 2>&1; then
    echo "✅ PostgreSQL password updated successfully."
else
    echo "❌ Failed to set PostgreSQL password."
    echo "   Ensure PostgreSQL is running."
fi
echo "-------------------------------------------------------"
