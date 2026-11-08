#!/bin/bash
# Builds Night Roll's live board library for Pin (and the probe that renders board pictures). Run after a UI change.
set -e
cd "$(dirname "$0")"
swift build --product NightRollBoards
swift build --product NightRollProbe
echo "library: $(pwd)/.build/debug/libNightRollBoards.dylib"
