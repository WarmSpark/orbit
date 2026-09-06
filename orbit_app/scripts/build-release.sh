#!/usr/bin/env bash
# Build a signed release APK for Orbit with production config baked in.
#
# Usage:
#   cp release.env.example release.env   # once — fill in your values
#   ./scripts/build-release.sh
#
# Output: build/app/outputs/flutter-apk/app-release.apk  (this is the file you
# put behind the "Download" button on the landing page).

set -euo pipefail

# Resolve repo root (this script lives in <root>/scripts/) regardless of cwd.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/release.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy release.env.example to release.env and fill it in." >&2
  exit 1
fi

# Load config (KEY=VALUE lines). `set -a` exports everything sourced.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# ---- validate ----
fail=0
if [[ -z "${ORBIT_BASE_URL:-}" ]]; then
  echo "ERROR: ORBIT_BASE_URL is empty in release.env" >&2; fail=1
elif [[ "$ORBIT_BASE_URL" != https://* ]]; then
  echo "ERROR: ORBIT_BASE_URL must start with https:// (got: $ORBIT_BASE_URL)." >&2
  echo "       Release builds block cleartext HTTP, so http:// would never connect." >&2
  fail=1
fi
if [[ "$ORBIT_BASE_URL" == */ ]]; then
  echo "ERROR: ORBIT_BASE_URL must not have a trailing slash (got: $ORBIT_BASE_URL)." >&2; fail=1
fi
if [[ -z "${ORBIT_GOOGLE_CLIENT_ID:-}" ]]; then
  echo "ERROR: ORBIT_GOOGLE_CLIENT_ID is empty in release.env" >&2; fail=1
fi
if [[ ! -f "$ROOT/android/key.properties" ]]; then
  echo "ERROR: android/key.properties not found — the APK would be debug-signed." >&2
  echo "       Restore your release keystore before building for distribution." >&2
  fail=1
fi
[[ "$fail" -eq 0 ]] || exit 1

echo "Building signed release APK"
echo "  ORBIT_BASE_URL         = $ORBIT_BASE_URL"
echo "  ORBIT_GOOGLE_CLIENT_ID = $ORBIT_GOOGLE_CLIENT_ID"
echo "  (ORBIT_DEV_AUTH is intentionally NOT set — dev login stays off)"
echo

flutter build apk --release \
  --dart-define=ORBIT_BASE_URL="$ORBIT_BASE_URL" \
  --dart-define=ORBIT_GOOGLE_CLIENT_ID="$ORBIT_GOOGLE_CLIENT_ID"

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo
if [[ -f "$APK" ]]; then
  size="$(du -h "$APK" | cut -f1)"
  echo "Done: $APK ($size)"
  echo "This is the file to upload behind the landing-page Download button."
else
  echo "Build finished but APK not found at expected path: $APK" >&2
  exit 1
fi
