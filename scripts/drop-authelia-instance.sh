#!/usr/bin/env bash

# drop-authelia-instance.sh
# Stops the Authelia service and wipes all state (DB, state dir, secrets).
# USE WITH EXTREME CAUTION.

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (sudo)." 
   exit 1
fi

read -p "⚠️  This will PERMANENTLY DELETE all Authelia data, secrets, and database. Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

echo "🛑 Stopping Authelia service..."
systemctl stop authelia-main.service 2>/dev/null

echo "🗑️  Dropping PostgreSQL database..."
sudo -u postgres psql -c "DROP DATABASE IF EXISTS authelia;" 2>/dev/null
sudo -u postgres psql -c "DROP USER IF EXISTS \"authelia-main\";" 2>/dev/null

echo "🧹 Cleaning up state directory..."
rm -rf /var/lib/authelia-main/*

echo "🤫 Cleaning up secrets..."
rm -rf /var/lib/secrets/authelia/*

echo "✨ Authelia instance dropped. You can now run generate-authelia-secrets.sh to start fresh."
