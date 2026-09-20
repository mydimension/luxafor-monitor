#!/usr/bin/env bash
#
# sigstore-sign.sh - Sign a release artifact (the DMG) with Sigstore/cosign.
#
# Usage:
#   Scripts/sigstore-sign.sh <path-to-file>
#
# This performs KEYLESS signing: no private key or secret is held by
# maintainers. In GitHub Actions, cosign uses the workflow's own OIDC
# token (via the `id-token: write` permission - see release.yml) to prove
# "this signature was produced by this exact GitHub Actions workflow run"
# and gets a short-lived certificate from Sigstore's public Fulcio CA;
# the signature is also logged to Sigstore's public Rekor transparency
# log. Run outside of CI (e.g. by a maintainer testing locally), cosign
# instead opens a browser for an interactive OIDC login (e.g. a Google/
# GitHub/Microsoft identity) - either way, no secret material is
# stored in this repo.
#
# This proves the artifact was produced by this repository/workflow and
# hasn't been modified since - it does NOT satisfy Apple Gatekeeper /
# notarization, which is unrelated. See README.md's "Installing a
# release" section for the distinction.
#
# Requires: cosign (https://docs.sigstore.dev/cosign/installation/).
# In CI this is installed via the `sigstore/cosign-installer` action
# before this script runs.
#
# Outputs (next to the input file):
#   <file>.sig   - the signature, base64-encoded
#   <file>.pem   - the signing certificate bundle (used to verify)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <path-to-file>" >&2
  exit 1
fi

TARGET_PATH="$1"

if [[ ! -f "${TARGET_PATH}" ]]; then
  echo "error: file not found: ${TARGET_PATH}" >&2
  exit 1
fi

if ! command -v cosign >/dev/null 2>&1; then
  echo "error: cosign not found on PATH." >&2
  echo "Install it: https://docs.sigstore.dev/cosign/installation/" >&2
  echo "(in CI this is done via the sigstore/cosign-installer action)" >&2
  exit 1
fi

SIGNATURE_PATH="${TARGET_PATH}.sig"
CERTIFICATE_PATH="${TARGET_PATH}.pem"

echo "==> Signing ${TARGET_PATH} with cosign (keyless)"
cosign sign-blob \
  --yes \
  --output-signature "${SIGNATURE_PATH}" \
  --output-certificate "${CERTIFICATE_PATH}" \
  "${TARGET_PATH}"

echo "==> Wrote:"
echo "    ${SIGNATURE_PATH}"
echo "    ${CERTIFICATE_PATH}"
echo ""
echo "Verify with:"
echo "  cosign verify-blob \\"
echo "    --certificate ${CERTIFICATE_PATH} \\"
echo "    --signature ${SIGNATURE_PATH} \\"
echo "    --certificate-identity-regexp \"https://github.com/OWNER/luxafor-monitor/.github/workflows/release.yml@.*\" \\"
echo "    --certificate-oidc-issuer \"https://token.actions.githubusercontent.com\" \\"
echo "    ${TARGET_PATH}"
