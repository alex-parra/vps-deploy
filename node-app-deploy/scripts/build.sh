#!/usr/bin/env bash

set -euo pipefail

echo " " # blank line
echo "----------------------------------------"
echo "- [scripts/build.sh] Building..."
mkdir -p ./build
cp -r ./src/* ./build/

if [ ! -d ".git" ]; then
  echo " " # blank line
  echo "- [scripts/build.sh] Cleaning up..."
  rm -rf _deploy .github scripts
  rm .gitignore README.md
fi

echo " " # blank line
echo "- [scripts/build.sh] Done"
echo "----------------------------------------"
echo " " # blank line
