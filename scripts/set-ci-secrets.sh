#!/bin/bash
# Sets the GitHub secrets release.yml needs to sign and notarize the DMG.
# Usage: scripts/set-ci-secrets.sh path/to/DeveloperID.p12
#
# The .p12 is the "Developer ID Application" identity exported from Keychain Access
# (My Certificates → right-click → Export). gh asks for its password; nothing is echoed.
# The notary key is read from ~/.appstoreconnect/private_keys/AuthKey_<ID>.p8.
set -euo pipefail
cd "$(dirname "$0")/.."

P12="${1:?Usage: $0 path/to/DeveloperID.p12}"
KEY_ID="${NOTARY_KEY_ID:-XWFYLU4573}"
ISSUER="${NOTARY_ISSUER:-69a6de74-0c7e-47e3-e053-5b8c7c11a4d1}"
P8="$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8"
[ -f "$P12" ] || { echo "No file at $P12" >&2; exit 1; }
[ -f "$P8" ] || { echo "No API key at $P8" >&2; exit 1; }

gh secret set DEVELOPER_ID -b "Developer ID Application: Nicholas Kuhne (WYMF4736GN)"
gh secret set NOTARY_KEY_ID -b "$KEY_ID"
gh secret set NOTARY_ISSUER -b "$ISSUER"
base64 -i "$P12" | gh secret set DEVELOPER_ID_P12
base64 -i "$P8" | gh secret set NOTARY_KEY_P8
echo "Password you gave the .p12 when exporting it:"
gh secret set DEVELOPER_ID_P12_PASSWORD
gh secret list
