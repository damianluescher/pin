#!/bin/sh
# Rebuilds the live Foundable boards from the current code. Optional: ./build.sh "<Pin home>" also writes live.json there.
set -e
cd "$(dirname "$0")"
node build.mjs
python3 live_config.py "${1:-$HOME/Library/Application Support/Pin}"
