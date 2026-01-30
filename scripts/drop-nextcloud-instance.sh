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
systemctl stop nextcloud-setup.service nextcloud-cron.service phpfpm-nextcloud.service nginx.service

echo "🗑️  Dropping PostgreSQL database and user..."
# Use -f to ignore errors if they don't exist
sudo -u postgres psql -c "DROP DATABASE IF EXISTS nextcloud;"
sudo -u postgres psql -c "DROP ROLE IF EXISTS nextcloud;"

echo "📂 Erasing Nextcloud data and secrets..."
# Deep clean including hidden files
rm -rf /var/lib/nextcloud/.* 2>/dev/null || true
rm -rf /var/lib/nextcloud/*
rm -rf /var/lib/secrets/nextcloud/*

echo "✅ Nextcloud instance dropped."
