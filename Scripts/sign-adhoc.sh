#!/usr/bin/env bash
#
# sign-adhoc.sh - Ad-hoc code-sign the LuxaforMonitor.app bundle.
#
# Usage:
#   Scripts/sign-adhoc.sh [path-to-app]
#
# Arguments (optional):
#   path-to-app   Default: dist/LuxaforMonitor.app
#
# This project has no paid Apple Developer ID, so releases cannot be
# signed with a real Developer ID certificate and cannot be notarized.
# "Ad-hoc" signing (`codesign --sign -`) is the best available option: it
# satisfies the baseline macOS requirement that a downloaded binary be
# signed at all, and lets `codesign --verify` succeed locally, but it does
# NOT satisfy Gatekeeper's notarization check - users will still see an
# "unidentified developer" warning on first launch. This is documented for
# end users in README.md.
#
# See Scripts/sigstore-sign.sh for the separate (and unrelated) step of
# signing the final DMG with Sigstore/cosign for tamper-evidence.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_PATH="${1:-${REPO_ROOT}/dist/LuxaforMonitor.app}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: app bundle not found at ${APP_PATH}" >&2
  echo "Run Scripts/build-app.sh first." >&2
  exit 1
fi

echo "==> Ad-hoc signing ${APP_PATH}"
codesign --force --deep --sign - "${APP_PATH}"

echo "==> Verifying signature"
codesign --verify --verbose=2 "${APP_PATH}"

echo "==> Done. Note: this is an ad-hoc signature, not a notarized"
echo "    Developer ID signature. Gatekeeper will still warn on first"
echo "    launch for anyone who downloads this app; see README.md."
