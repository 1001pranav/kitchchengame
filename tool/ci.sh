#!/usr/bin/env bash
# Every check that must pass before a change is done (doc 08 §7).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$root/packages/sim_core"
dart pub get >/dev/null
dart format --set-exit-if-changed .
dart analyze --fatal-infos
dart test

cd "$root/app"
flutter pub get >/dev/null
flutter analyze
flutter test
echo "All checks passed."
