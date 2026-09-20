#!/usr/bin/env bash
#
# build-app.sh - Assemble LuxaforMonitor.app from the SwiftPM release binary.
#
# Usage:
#   Scripts/build-app.sh [version] [output-dir]
#
# Arguments (all optional):
#   version      App version, used for CFBundleVersion/CFBundleShortVersionString.
#                Default: 0.1.0 (or $APP_VERSION env var if set).
#   output-dir   Where to stage the .app bundle. Default: dist/
#
# Env vars:
#   APP_VERSION           Same as the version argument (argument wins if both given).
#   BUNDLE_IDENTIFIER     Default: com.luxaformonitor.app
#   SKIP_SWIFT_BUILD      If set to "1", skip running `swift build` and use
#                          whatever is already in .build/release/ (useful for
#                          CI where the build step already ran separately).
#
# What it does:
#   1. Runs `swift build -c release` for the LuxaforMonitorApp executable
#      target (unless SKIP_SWIFT_BUILD=1).
#   2. Creates <output-dir>/LuxaforMonitor.app/Contents/{MacOS,Resources}.
#   3. Copies the built executable into Contents/MacOS/LuxaforMonitor.
#   4. Renders Scripts/Info.plist.template into Contents/Info.plist with the
#      given version/identifier substituted in.
#
# This script does NOT code-sign or package the app - see sign-adhoc.sh and
# package-dmg.sh for those steps.
#
# Known assumption (flagged for whoever wires this up against the real
# Swift source): this script expects `swift build -c release` to produce a
# single-architecture binary at `.build/release/LuxaforMonitorApp`, which
# is SwiftPM's default for the `LuxaforMonitorApp` executable target
# declared in Package.swift. If the release pipeline is later changed to
# build a universal (arm64 + x86_64) binary via
# `swift build -c release --arch arm64 --arch x86_64`, SwiftPM instead
# writes to `.build/apple/Products/Release/LuxaforMonitorApp` and this
# script's BINARY_PATH detection below will need that path added - it
# already checks both locations, but this has not been exercised against a
# real build yet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="LuxaforMonitor"
EXECUTABLE_TARGET="LuxaforMonitorApp"
BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-com.luxaformonitor.app}"

VERSION="${1:-${APP_VERSION:-0.1.0}}"
OUTPUT_DIR="${2:-${REPO_ROOT}/dist}"

echo "==> Building ${APP_NAME}.app version ${VERSION}"

if [[ "${SKIP_SWIFT_BUILD:-0}" != "1" ]]; then
  echo "==> Running swift build -c release"
  (cd "${REPO_ROOT}" && swift build -c release --product "${EXECUTABLE_TARGET}")
else
  echo "==> SKIP_SWIFT_BUILD=1, skipping swift build"
fi

# SwiftPM's default (single-arch) release output location, with the
# universal-binary output location as a fallback in case the build was
# invoked with multiple --arch flags.
CANDIDATE_PATHS=(
  "${REPO_ROOT}/.build/release/${EXECUTABLE_TARGET}"
  "${REPO_ROOT}/.build/apple/Products/Release/${EXECUTABLE_TARGET}"
)

BINARY_PATH=""
for candidate in "${CANDIDATE_PATHS[@]}"; do
  if [[ -f "${candidate}" ]]; then
    BINARY_PATH="${candidate}"
    break
  fi
done

if [[ -z "${BINARY_PATH}" ]]; then
  echo "error: could not find built binary '${EXECUTABLE_TARGET}' in any of:" >&2
  printf '  %s\n' "${CANDIDATE_PATHS[@]}" >&2
  echo "Did 'swift build -c release --product ${EXECUTABLE_TARGET}' succeed?" >&2
  exit 1
fi

echo "==> Using binary: ${BINARY_PATH}"

APP_BUNDLE="${OUTPUT_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Staging bundle at ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${BINARY_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

TEMPLATE_PATH="${SCRIPT_DIR}/Info.plist.template"
if [[ ! -f "${TEMPLATE_PATH}" ]]; then
  echo "error: missing template ${TEMPLATE_PATH}" >&2
  exit 1
fi

sed \
  -e "s/__BUNDLE_EXECUTABLE__/${APP_NAME}/g" \
  -e "s/__BUNDLE_IDENTIFIER__/${BUNDLE_IDENTIFIER}/g" \
  -e "s/__BUNDLE_NAME__/Luxafor Monitor/g" \
  -e "s/__BUNDLE_VERSION__/${VERSION}/g" \
  -e "s/__BUNDLE_SHORT_VERSION__/${VERSION}/g" \
  "${TEMPLATE_PATH}" > "${CONTENTS_DIR}/Info.plist"

echo "==> Wrote ${CONTENTS_DIR}/Info.plist"
echo "==> Built ${APP_BUNDLE}"
