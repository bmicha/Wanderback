#!/bin/bash
# Construit la cible iOS, l'installe sur un simulateur, la lance avec les
# arguments donnés et capture l'écran.
#
#   scripts/shot-ios.sh "iPhone 17" /tmp/game.png -demoMode -noMosaic -screen game
#
# Écrans atteignables : -screen game | reveal | summary (avec -demoMode).
# Sans -screen : l'accueil. -noMosaic masque les photos personnelles du fond.
set -euo pipefail

SIM="${1:?usage: shot-ios.sh <simulateur> <sortie.png> [args de lancement...]}"
OUT="${2:?usage: shot-ios.sh <simulateur> <sortie.png> [args de lancement...]}"
shift 2

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${DD:-$ROOT/.build-sim}"

xcodebuild -project "$ROOT/Wanderback.xcodeproj" -scheme WanderbackiOS \
  -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath "$DD" build > /dev/null

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b > /dev/null
xcrun simctl install "$SIM" "$DD/Build/Products/Debug-iphonesimulator/Wanderback.app"
xcrun simctl terminate "$SIM" com.bastien.Wanderback 2>/dev/null || true
xcrun simctl launch "$SIM" com.bastien.Wanderback "$@" > /dev/null

# Laisse le temps au premier rendu SwiftUI (et à l'animation d'apparition)
sleep 4

xcrun simctl io "$SIM" screenshot "$OUT"
echo "→ $OUT"
