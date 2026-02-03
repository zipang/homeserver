#!/usr/bin/env bash

# generate-zrok-secrets.sh
# This script initializes the manual secret files for zrok on SKYLAB.

SECRETS_DIR="/var/lib/secrets/zrok"
CONTROLLER_ENV="$SECRETS_DIR/controller.env"
FRONTEND_ENV="$SECRETS_DIR/frontend.env"

# Ensure directory exists with strict permissions
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Helper to generate random strings
gen_secret() {
    LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$1"
}

if [ ! -f "$CONTROLLER_ENV" ]; then
    echo "Creating $CONTROLLER_ENV..."
    ZROK_ADMIN_TOKEN=$(gen_secret 32)
    ZITI_PWD=$(gen_secret 24)
    
    cat <<EOF > "$CONTROLLER_ENV"
ZROK_ADMIN_TOKEN=$ZROK_ADMIN_TOKEN
ZITI_PWD=$ZITI_PWD
EOF
    chmod 600 "$CONTROLLER_ENV"
fi

if [ ! -f "$FRONTEND_ENV" ]; then
    echo "Creating $FRONTEND_ENV template..."
    # Note: Google Client ID/Secret must be filled manually by the user
    ZROK_OAUTH_HASH_KEY=$(gen_secret 32)
    
    cat <<EOF > "$FRONTEND_ENV"
# Google OAuth Credentials (Required for SSO)
ZROK_OAUTH_GOOGLE_CLIENT_ID=REPLACE_ME_WITH_GOOGLE_CLIENT_ID
ZROK_OAUTH_GOOGLE_CLIENT_SECRET=REPLACE_ME_WITH_GOOGLE_CLIENT_SECRET

# 32-character random string for signing/encrypting OAuth cookies
ZROK_OAUTH_HASH_KEY=$ZROK_OAUTH_HASH_KEY
EOF
    chmod 600 "$FRONTEND_ENV"
fi

echo "Secrets initialized in $SECRETS_DIR."
echo "Please manually edit $FRONTEND_ENV to add your Google OAuth credentials."
