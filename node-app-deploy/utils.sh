#!/bin/false

set -euo pipefail

# Helpers -----------------------------------------------------------------------------

# Function to print colored text
print_color() {
  local color="$1"
  local text="$2"
  case "$color" in
  "red") echo -e "\033[31m$text\033[0m" ;;
  "green") echo -e "\033[32m$text\033[0m" ;;
  "yellow") echo -e "\033[33m$text\033[0m" ;;
  "blue") echo -e "\033[34m$text\033[0m" ;;
  "purple") echo -e "\033[35m$text\033[0m" ;;
  "cyan") echo -e "\033[36m$text\033[0m" ;;
  *) echo "$text" ;;
  esac
}

# Usage: log "message" [color]
# Prints a log message with optional color and timestamp
# Colors: red, green, yellow, blue, purple, cyan
log() {
  local color="${2:-}"
  echo -e "🤖 $(print_color "$color" "$1") \033[33m[$(date +'%H:%M:%S')]\033[0m"
}

logSection() {
  echo " " # blank line
  echo "----------------------------------------"
  log "$1"
}

logInfo() {
  log "- $1" blue
}

logError() {
  log "- $1" red
}

logSuccess() {
  log "- $1" green
}

# Get next available port in the specified range (default: 4000-5000)
# Usage example:
# PORT=$(get_available_port)        # Uses default range 4000-5000
# PORT=$(get_available_port 3000)   # Uses range 3000-5000
# PORT=$(get_available_port 3000 3500) # Uses range 3000-3500
function get_available_port() {
  local start=${1:-4000}
  local end=${2:-5000}
  echo $(comm -23 <(seq $start $end | sort) <(ss -Htan | awk '{print $4}' | cut -d':' -f2 | sort -u) | head -n 1)
}
