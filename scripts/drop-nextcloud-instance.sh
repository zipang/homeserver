#!/usr/bin/env bash

# drop-nextcloud-instance.sh
# DANGER: This script erases Nextcloud data and database.
# Should be run with sudo.

echo "⚠️  WARNING: This will permanently delete Nextcloud data and database!"
read -p "Are you sure you want to proceed? (y/N) " confirm

if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
    echo "Aborted."
    exit 1
fi

echo "🛑 Stopping services..."
systemctl stop nextcloud-setup.service phpfpm-nextcloud.service nginx.service

echo "🗑️  Dropping PostgreSQL database and user..."
sudo -u postgres psql -c "DROP DATABASE nextcloud;"
sudo -u postgres psql -c "DROP ROLE nextcloud;"

echo "📂 Erasing Nextcloud data and secrets..."
rm -rf /var/lib/nextcloud/*
rm -rf /var/lib/secrets/nextcloud/*

# Reset ownership of the root directory to ensure nextcloud can recreate subdirs
chown nextcloud:nextcloud /var/lib/nextcloud
chmod 750 /var/lib/nextcloud

echo "✅ Nextcloud instance dropped."
