#!/usr/bin/env bash

set -euo pipefail

echo " " # blank line
echo "Building..."
mkdir -p ./build
cp -r ./src/* ./build/

if [ ! -d ".git" ]; then
  echo " " # blank line
  echo "Cleaning up..."
  rm -rf _deploy .github scripts
  rm .gitignore README.md
fi
