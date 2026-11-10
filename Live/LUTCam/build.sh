#!/bin/bash
# Builds LUT Cam's live board library for Pin (and the probe that renders board pictures). Run after a UI change.
set -e
cd "$(dirname "$0")"
swift build --product LUTCamBoards
swift build --product LUTCamProbe
echo "library: $(pwd)/.build/debug/libLUTCamBoards.dylib"
# Fresh board pictures for Pin's zoomed-out view (they went stale on 10 Nov 2026).
rm -rf /tmp/lutcam-board-pics
"$(swift build --show-bin-path)/LUTCamProbe" render /tmp/lutcam-board-pics 2 > /dev/null
./refresh-pictures.py /tmp/lutcam-board-pics
