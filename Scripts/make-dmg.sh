#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="Iconic"
APP_VERSION="1.0"
DMG_NAME="Iconic-1.0-arm64.dmg"
VOLUME_NAME="Iconic 1.0"
SOURCE_APP="${PROJECT_ROOT}/build/DD/Build/Products/Debug/Iconic.app"
DIST_DIR="${PROJECT_ROOT}/dist"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
STAGING_DIR="${DIST_DIR}/Iconic-staging"

if [ ! -d "${SOURCE_APP}" ]; then
    echo "ERROR: Source app not found at: ${SOURCE_APP}" >&2
    exit 1
fi

mkdir -p "${DIST_DIR}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
trap 'echo "Error: cleaning up staging directory..." >&2; rm -rf "${STAGING_DIR}"; exit 1' ERR INT TERM

echo "Copying ${APP_NAME}.app into staging directory..."
cp -R "${SOURCE_APP}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating DMG: ${DMG_PATH}"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRO \
    -size 200m \
    "${DMG_PATH}"

rm -rf "${STAGING_DIR}"
trap - ERR INT TERM

echo ""
echo "DMG created successfully:"
echo "  Path: ${DMG_PATH}"
echo ""
ls -lh "${DMG_PATH}"
