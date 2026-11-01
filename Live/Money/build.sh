#!/bin/sh
# Makes a working copy of Money's page with invented data in dist/ and writes live.json. Never reads ~/tools/money/data.json.
# Optional: ./build.sh "<Pin home>".
set -e
cd "$(dirname "$0")"
D="$HOME/tools/money/design"
rm -rf dist; mkdir -p dist
cp -R "$D/icons" "$D/logos" "$D/Inter.woff2" dist/
cp src/standin.js src/invented.js dist/
python3 make_page.py "$D/mockup.html" dist/index.html
python3 live_config.py "${1:-$HOME/Library/Application Support/Pin}"
