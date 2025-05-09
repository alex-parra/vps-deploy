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
mkdir -p "$BASE/logs"
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
      // Adjusted for multi-app environment
      instances: 1, // Single instance per app
      exec_mode: 'fork', // Use fork mode instead of cluster
      max_memory_restart: '512M', // More conservative memory limit
      exp_backoff_restart_delay: 100,
      max_restarts: 10,
      min_uptime: '30s',
      watch: false,
      merge_logs: true,
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: 'logs/error.log',
      out_file: 'logs/out.log',
      time: true,
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

  # Security headers
  add_header X-Frame-Options 'SAMEORIGIN' always;
  add_header X-XSS-Protection '1; mode=block' always;
  add_header X-Content-Type-Options 'nosniff' always;
  add_header Referrer-Policy 'no-referrer-when-downgrade' always;
  add_header Content-Security-Policy 'default-src \'self\' http: https: data: blob: \'unsafe-inline\'' always;
  add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;

  # Logging
  access_log /var/log/nginx/$DOMAIN.access.log combined buffer=512k flush=1m;
  error_log /var/log/nginx/$DOMAIN.error.log warn;

  # Client body settings
  client_max_body_size 10M;
  client_body_buffer_size 128k;
  client_header_buffer_size 1k;

  # Timeouts
  client_body_timeout 12;
  client_header_timeout 12;
  keepalive_timeout 15;
  send_timeout 10;

  # Gzip compression
  gzip on;
  gzip_vary on;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

  # Proxy settings
  location / {
    proxy_pass http://localhost:$PORT;
    proxy_http_version 1.1;

    # WebSocket support
    proxy_set_header Upgrade \\\$http_upgrade;
    proxy_set_header Connection 'upgrade';

    # Standard headers
    proxy_set_header Host \\\$host;
    proxy_set_header X-Real-IP \\\$remote_addr;
    proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \\\$scheme;

    # Timeouts
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    # Buffers
    proxy_buffer_size 4k;
    proxy_buffers 4 32k;
    proxy_busy_buffers_size 64k;
    proxy_temp_file_write_size 64k;

    # Cache bypass
    proxy_cache_bypass \\\$http_upgrade;

    # Security
    proxy_hide_header X-Powered-By;
    proxy_hide_header X-AspNet-Version;
  }

  # Deny access to hidden files
  location ~ /\\. {
      deny all;
      access_log off;
      log_not_found off;
  }

  # Deny access to backup files
  location ~ ~$ {
    deny all;
    access_log off;
    log_not_found off;
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
