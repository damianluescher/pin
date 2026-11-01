#!/bin/bash
# Fresh screens from phone-renew, then the library Pin loads. Touches nothing in phone-renew.
set -euo pipefail
cd "$(dirname "$0")"
python3 sync.py
exec swift build --product TenOldBoards "$@"
