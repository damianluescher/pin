#!/bin/bash
# Fresh screens from AutoBalance, then the library Pin loads. Touches nothing in AutoBalance.
set -euo pipefail
cd "$(dirname "$0")"
python3 sync.py
exec swift build --product AutoBalanceBoards "$@"
