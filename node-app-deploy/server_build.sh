#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $SCRIPT_DIR/utils.sh

REPO_URL="$REPO_URL" # set in environment by init.sh
DOMAIN="$DOMAIN"     # set in environment by init.sh

REPO_NAME=$(basename "$REPO_URL" ".${REPO_URL##*.}") # get repository name without user and extension

REPO_DIR="repo" # directory where the repository is cloned
BKP_DIR="bkp"   # directory where backup is stored
LIVE_DIR="live" # directory where live app is served from

USER="$(whoami)"
BASE="$HOME/$REPO_NAME"
mkdir -p "$BASE" && cd "$BASE"

# ------------------------------------------------------------------------------
logSection "Determine port..."
PORT=""
# get the port from the nginx config file
NGINX_CONFIG="/etc/nginx/sites-available/$DOMAIN"
[ -f "$NGINX_CONFIG" ] && PORT=$(grep -oP 'proxy_pass http://localhost:\K\d+' "$NGINX_CONFIG")
# if the port is not set, get a new available port
[ -z "$PORT" ] && PORT=$(get_available_port 4000 5000)
if [ -z "$PORT" ]; then
  logError "error: failed to determine port" && exit 1
fi
logSuccess "Port: $PORT"

# ------------------------------------------------------------------------------
logSection "Cloning repository..."
rm -rf "./$REPO_DIR"
git clone --quiet -b main --single-branch --depth=1 "$REPO_URL" "./$REPO_DIR"
rm -rf "./$REPO_DIR/.git"
logSuccess "Repository cloned"

# ------------------------------------------------------------------------------
logSection "Installing dependencies and building..."
mv "./.env" "./$REPO_DIR/"
npm ci --prefix "./$REPO_DIR" --no-fund --no-audit
npm run build --prefix "./$REPO_DIR"
logSuccess "Dependencies installed and built"

# ------------------------------------------------------------------------------
if [ -d "./$LIVE_DIR" ]; then
  logSection "Backing up the current live build..."
  rsync -a --delete "./$LIVE_DIR/" "./$BKP_DIR/"
  logSuccess "Backup created"
fi

# ------------------------------------------------------------------------------
logSection "Moving new build to live directory..."
rm -rf "./$LIVE_DIR"
mv "./$REPO_DIR" "./$LIVE_DIR"
logSuccess "New build moved to live directory"

# ------------------------------------------------------------------------------
logSection "Ensuring all files are owned by $USER..."
chown -R $USER:$USER "$BASE"
logSuccess "All files are owned by $USER"

# ------------------------------------------------------------------------------
logSection "PM2 (re)start app..."
cd "$BASE/$LIVE_DIR"
cat >pm2.config.cjs <<EON
module.exports = {
  apps: [
    {
      name: '$REPO_NAME',
      script: 'npm',
      args: 'run start',
      increment_var: 'PORT',
      env: {
        NODE_ENV: 'production',
        PORT: $PORT,
      },
    },
  ],
};
EON
pm2 restart pm2.config.cjs && pm2 save
logSuccess "PM2 app restarted"

# ------------------------------------------------------------------------------
logSection "Checking if app is listening on port $PORT..."
retry_count=0
while [ $retry_count -lt 5 ]; do
  if ! netstat -tuln | grep :$PORT; then
    retry_count=$((retry_count + 1))
    if [ $retry_count -eq 5 ]; then
      logError "error: app not listening on port $PORT"
      exit 1
    fi
    logInfo "retrying ($retry_count / 5)"
    sleep 5
  else
    break
  fi
done
logSuccess "App is listening on port $PORT"

# ------------------------------------------------------------------------------
logSection "Configuring Nginx..."
sudo bash -c "cat >/etc/nginx/sites-available/$DOMAIN <<EON
server {
  listen 80;
  server_name $DOMAIN;
  access_log /var/log/nginx/$DOMAIN.access.log;
  error_log /var/log/nginx/$DOMAIN.error.log;
  location / {
    proxy_pass http://localhost:$PORT;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \\\$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \\\$host;
    proxy_cache_bypass \\\$http_upgrade;
    proxy_set_header X-Real-IP \\\$remote_addr;
    proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
  }
}
EON"

sudo ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
sudo systemctl restart nginx >/dev/null
logSuccess "Nginx configured"

# ------------------------------------------------------------------------------
logSection "Cleaning up..."
sudo apt-get autoremove -y
sudo apt-get clean
history -c
rm -rf "$BASE/_deploy"
