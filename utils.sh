#!/usr/bin/env bash

set -euo pipefail

# Helpers -----------------------------------------------------------------------------

# Default separator is space if not provided
function strToArr() {
  echo "$1" | tr "${2:- }" "\n"
}

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

# Main -----------------------------------------------------------------------------

DB_NAME="alex parra test"

IFS=' ' read -ra DBS <<<"$DB_NAME"
echo ${DBS[1]}

# DBA=($(echo "$DB_NAME" | tr " " "\n"))
DBA=($(strToArr "$DB_NAME"))
echo ${DBA[1]}
