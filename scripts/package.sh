#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ADDON_NAME="RPQuest"
MANIFEST_FILE="${ADDON_NAME}.txt"
DIST_DIR="${ROOT_DIR}/dist"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  echo "Error: $MANIFEST_FILE not found in $ROOT_DIR" >&2
  exit 1
fi

# Auto-compute AddOnVersion (monotonically increasing integer from git commit count)
# and Version from exact SemVer tag (e.g. v1.0.0 -> 1.0.0), falling back to manifest Version.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ADDON_VERSION="$(git rev-list --count HEAD)"
  EXACT_TAG="$(git describe --tags --exact-match 2>/dev/null || true)"
  if [[ -n "$EXACT_TAG" ]]; then
    DISPLAY_VERSION="${EXACT_TAG#v}"
  else
    LATEST_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    if [[ -n "$LATEST_TAG" ]]; then
      DISPLAY_VERSION="${LATEST_TAG#v}"
    else
      DISPLAY_VERSION="$(awk -F': *' '/^## Version:/{print $2; exit}' "$MANIFEST_FILE" | tr -d '\r')"
    fi
  fi
else
  ADDON_VERSION="$(awk -F': *' '/^## AddOnVersion:/{print $2; exit}' "$MANIFEST_FILE" | tr -d '\r')"
  DISPLAY_VERSION="$(awk -F': *' '/^## Version:/{print $2; exit}' "$MANIFEST_FILE" | tr -d '\r')"
fi

STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

TARGET_DIR="${STAGE_DIR}/${ADDON_NAME}"
mkdir -p "$TARGET_DIR"

# Copy runtime addon files only
cp -R RPQuest.lua Bindings.xml README.md readme.txt LICENSE src lang "$TARGET_DIR/"

# Stamp auto-computed Version, AddOnVersion, and Description version tag into staged manifest
awk -v ver="$DISPLAY_VERSION" -v aver="$ADDON_VERSION" '
  /^## Version:/      { print "## Version: " ver; next }
  /^## AddOnVersion:/ { print "## AddOnVersion: " aver; next }
  /^## Description:/  {
    if ($0 ~ /\(v[0-9]+\.[0-9]+\.[0-9]+[^)]*\)/) {
      sub(/\(v[0-9]+\.[0-9]+\.[0-9]+[^)]*\)/, "(v" ver ")")
    } else {
      $0 = $0 " (v" ver ")"
    }
    print; next
  }
  { print }
' "$MANIFEST_FILE" > "${TARGET_DIR}/${MANIFEST_FILE}"

# Verify every file referenced in the manifest exists in the staged addon
while IFS= read -r line; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" =~ ^# ]] && continue
  if [[ ! -f "${TARGET_DIR}/${line}" ]]; then
    echo "Error: manifest entry '$line' missing from staged package" >&2
    exit 1
  fi
done < "${TARGET_DIR}/${MANIFEST_FILE}"

OUT_ZIP="${DIST_DIR}/${ADDON_NAME}-${DISPLAY_VERSION}.zip"

mkdir -p "$DIST_DIR"
rm -f "${DIST_DIR}/${ADDON_NAME}"*.zip

(
  cd "$STAGE_DIR"
  zip -rq "$OUT_ZIP" "$ADDON_NAME" -x "*/.DS_Store" "*/Thumbs.db" "*~"
)

SIZE_BYTES="$(wc -c < "$OUT_ZIP" | tr -d ' ')"
echo "Packaged: $OUT_ZIP"
echo "Version:  $DISPLAY_VERSION (AddOnVersion: $ADDON_VERSION)"
echo "Size:     ${SIZE_BYTES} bytes"
