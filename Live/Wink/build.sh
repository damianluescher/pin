#!/bin/bash
# Fresh screens from wink2, then the library Pin loads. Touches nothing in wink2.
set -euo pipefail
cd "$(dirname "$0")"
python3 sync.py
exec swift build --product WinkBoards "$@"
