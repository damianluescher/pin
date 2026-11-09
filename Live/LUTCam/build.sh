#!/bin/bash
# Builds LUT Cam's live board library for Pin (and the probe that renders board pictures). Run after a UI change.
set -e
cd "$(dirname "$0")"
swift build --product LUTCamBoards
swift build --product LUTCamProbe
echo "library: $(pwd)/.build/debug/libLUTCamBoards.dylib"
