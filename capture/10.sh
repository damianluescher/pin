#!/bin/zsh
# Renders 10's four main screens with made-up data and adds them to Pin as new versions.
# Usage: capture/10.sh [--build] [today sleep train settings] (default all four)
set -euo pipefail
repo=~/tools/noop2; build=/tmp/pin-10-build; device="Pin iPhone"
if [ "${1:-}" = "--build" ] || [ ! -d "$build/Build/Products/Debug-iphonesimulator/NOOP.app" ]; then
  [ "${1:-}" = "--build" ] && shift
  xcodebuild -project "$repo/Strand.xcodeproj" -scheme NOOPiOS -configuration Debug -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$device" -derivedDataPath "$build" CODE_SIGNING_ALLOWED=NO build > /tmp/pin-10-build.log 2>&1 \
    || { tail -20 /tmp/pin-10-build.log; exit 1; }
fi
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" -b >/dev/null
xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 --batteryState charged --wifiBars 3 --cellularBars 4
xcrun simctl install booted "$build/Build/Products/Debug-iphonesimulator/NOOP.app"
xcrun simctl privacy booted grant all com.damian.Ten >/dev/null 2>&1 || true
screens=("$@"); [ ${#screens} -eq 0 ] && screens=(today sleep train settings)
for s in $screens; do
  name="${(C)s}"
  ~/.local/bin/pin capture sim 10 "$name" --bundle com.damian.Ten --arg --demo-seed --arg --ten-tab --arg "$s" --arg --ten-fake-strap \
    --arg --ten-seed-hr --arg -seedHistory --wait 9 --page Screens --source "$repo/StrandiOS/Ten/$name"
done
