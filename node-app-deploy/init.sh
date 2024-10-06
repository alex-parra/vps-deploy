#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $SCRIPT_DIR/utils.sh

REPO_URL=https://github.com/${GITHUB_REPOSITORY}.git
REPO_NAME=$(basename "$REPO_URL" ".${REPO_URL##*.}") # get repository name without user and extension
SERVER_IP="$SERVER_IP"                               # set in deploy.yml
DOMAIN="$DOMAIN"                                     # set in deploy.yml
ENV_FILE="$ENV_FILE"                                 # set in deploy.yml

# ------------------------------------------------------------------------------
logSection "Adding server to known hosts..."
(ssh-keyscan -H $SERVER_IP >>~/.ssh/known_hosts) 2> >(grep -vE '^#')
logSuccess "Server added to known hosts"

# ------------------------------------------------------------------------------
logSection "Copying deploy scripts to server..."
ssh vnlf@$SERVER_IP "mkdir -p ~/$REPO_NAME/_deploy"
rsync -aqz --delete $SCRIPT_DIR/ vnlf@$SERVER_IP:~/$REPO_NAME/_deploy/
ssh vnlf@$SERVER_IP "echo '$ENV_FILE' > ~/$REPO_NAME/.env"
logSuccess "Deploy scripts copied to server"

ENV_VARS=(
  "REPO_URL=$REPO_URL"
  "DOMAIN=$DOMAIN"
  # ... other variables that need to be made available to the server...
)

# ------------------------------------------------------------------------------
logSection "Running server build..."
ssh vnlf@$SERVER_IP "export ${ENV_VARS[*]} && bash ~/$REPO_NAME/_deploy/server_build.sh"

echo " " # blank line
log "Deployment successful! 🚀🚀🚀" green
