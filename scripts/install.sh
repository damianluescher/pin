#!/bin/zsh
# Installs the `boards` command for agents (and `pin`, its old name, as a hidden alias). Boards live only inside Wink
# now (27 Nov 2026, Damian: "its only inside of wink, called boards"): no separate app is built or installed any more.
# Wink links PinKit itself (~/tools/wink2/project.yml). The old Pin.app is kept in ~/.agents/backups/2026-11-27-pin-app/.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product pincli
bin=$(swift build -c release --show-bin-path)
mkdir -p ~/.local/bin ~/tools/pin/.bin
cp "$bin/pincli" ~/tools/pin/.bin/boards
ln -sf ~/tools/pin/.bin/boards ~/tools/pin/.bin/pin
ln -sf ~/tools/pin/.bin/boards ~/.local/bin/boards
ln -sf ~/tools/pin/.bin/boards ~/.local/bin/pin
echo installed
