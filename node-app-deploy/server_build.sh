#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
source $SCRIPT_DIR/utils.sh

REPO_NAME="$REPO_NAME" # set in environment by init.sh
DOMAIN="$DOMAIN"       # set in environment by init.sh
USER="$USER"           # set in environment by init.sh
BASE="$BASE"           # set in environment by init.sh

cd "$BASE" # created in init.sh
chown -R $USER:$USER "$BASE"

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
logSection "Installing dependencies and building..."
cd "./repo"
npm ci --no-fund --no-audit
npm run build
cd "$BASE"
logSuccess "Dependencies installed and built"

# ------------------------------------------------------------------------------
if [ -d "./live" ]; then
  logSection "Backing up the current live build..."
  rsync -a --delete "./live/" "./bkp/"
  logSuccess "Backup created"
fi

# ------------------------------------------------------------------------------
logSection "Moving new build to live directory..."
rm -rf "./live"
mv "./repo" "./live"
logSuccess "New build moved to live directory"

# ------------------------------------------------------------------------------
logSection "PM2 (re)start app..."
cd "$BASE/live"
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
