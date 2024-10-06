#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $SCRIPT_DIR/utils.sh

REPO_URL=https://github.com/${GITHUB_REPOSITORY}.git
REPO_NAME=$(basename "$REPO_URL" ".${REPO_URL##*.}") # get repository name without user and extension
SERVER_IP="$SERVER_IP"                               # set in deploy.yml
DOMAIN="$DOMAIN"                                     # set in deploy.yml
ENV_FILE="$ENV_FILE"                                 # set in deploy.yml
USER="$USER"                                         # set in deploy.yml

BASE="~/apps/$REPO_NAME"

# ------------------------------------------------------------------------------
logSection "Adding server to known hosts..."
(ssh-keyscan -H $SERVER_IP >>~/.ssh/known_hosts) 2> >(grep -vE '^#')
logSuccess "Server added to known hosts"

# ------------------------------------------------------------------------------
logSection "Copying code to server..."
ssh $USER@$SERVER_IP "mkdir -p $BASE/repo"
rsync -aqz --delete --exclude={'.git','.github'} $PWD/ $USER@$SERVER_IP:$BASE/repo/
ssh $USER@$SERVER_IP "cp -r $BASE/repo/_deploy $BASE/ && echo '$ENV_FILE' > $BASE/repo/.env"
logSuccess "Code sent to server"

ENV_VARS=(
  "REPO_NAME=$REPO_NAME"
  "DOMAIN=$DOMAIN"
  "USER=$USER"
  "BASE=$BASE"
  # ... other variables that need to be made available to the server...
)

# ------------------------------------------------------------------------------
logSection "Running server build..."
ssh $USER@$SERVER_IP "export ${ENV_VARS[*]} && bash $BASE/_deploy/server_build.sh"
ssh $USER@$SERVER_IP "rm -rf $BASE/_deploy"

echo " " # blank line
log "Deployment successful! 🚀🚀🚀" green
