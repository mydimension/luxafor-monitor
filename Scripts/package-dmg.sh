#!/usr/bin/env bash
#
# package-dmg.sh - Package the signed LuxaforMonitor.app into a .dmg.
#
# Usage:
#   Scripts/package-dmg.sh [version] [app-path] [output-dir]
#
# Arguments (all optional):
#   version      Used in the output filename, e.g. LuxaforMonitor-0.1.0.dmg.
#                Default: 0.1.0 (or $APP_VERSION env var if set).
#   app-path     Default: dist/LuxaforMonitor.app
#   output-dir   Default: dist/
#
# Tooling choice: this uses the built-in `hdiutil` rather than the
# third-party `create-dmg` tool. Both are reasonable choices; hdiutil was
# picked to keep the packaging pipeline dependency-free (consistent with
# this project's "no third-party dependencies" stance) and because it's
# guaranteed present on every macOS runner/dev machine with no `brew
# install` step required. The tradeoff is a plainer-looking DMG (no custom
# background image/icon layout) - if the project later wants a nicer
# installer window, swap this script's `hdiutil create` call for
# `create-dmg` (installed via `brew install create-dmg` in CI) without
# needing to change anything that calls this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION="${1:-${APP_VERSION:-0.1.0}}"
APP_PATH="${2:-${REPO_ROOT}/dist/LuxaforMonitor.app}"
OUTPUT_DIR="${3:-${REPO_ROOT}/dist}"

VOLUME_NAME="Luxafor Monitor"
DMG_NAME="LuxaforMonitor-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "error: app bundle not found at ${APP_PATH}" >&2
  echo "Run Scripts/build-app.sh (and Scripts/sign-adhoc.sh) first." >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "${STAGING_DIR}"' EXIT

echo "==> Staging DMG contents in ${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

mkdir -p "${OUTPUT_DIR}"
rm -f "${DMG_PATH}"

echo "==> Creating ${DMG_PATH}"
hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "==> Generating checksum"
CHECKSUM_PATH="${DMG_PATH}.sha256"
(cd "${OUTPUT_DIR}" && shasum -a 256 "${DMG_NAME}" > "$(basename "${CHECKSUM_PATH}")")

# Also produce/refresh a combined SHA256SUMS file covering every .dmg
# currently in the output dir, which is what release.yml uploads.
(cd "${OUTPUT_DIR}" && shasum -a 256 ./*.dmg > SHA256SUMS)

echo "==> Done."
echo "    DMG:      ${DMG_PATH}"
echo "    Checksum: ${CHECKSUM_PATH}"
echo "    Combined: ${OUTPUT_DIR}/SHA256SUMS"
