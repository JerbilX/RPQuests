#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage: ./scripts/bump-version.sh [OPTIONS] [major|minor|patch]

Calculate the next SemVer version from Conventional Commits since the latest
vX.Y.Z git tag (or apply an explicit bump/version) and update version metadata
across RPQuest.txt, src/Constants.lua, README.md, and README.es.md.

Options:
  --dry-run             Preview the calculated version and file diffs without writing
  --version <X.Y.Z>     Set an explicit target SemVer (e.g. 1.7.0 or 1.7.0-dev)
  -h, --help            Show this help message

Positional override:
  major | minor | patch Force a specific SemVer component bump
EOF
}

DRY_RUN=0
EXPLICIT_VERSION=""
OVERRIDE_BUMP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --version)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Error: --version requires a SemVer argument (e.g. 1.7.0)." >&2
        exit 1
      fi
      EXPLICIT_VERSION="${2#v}"
      shift 2
      ;;
    major|minor|patch)
      if [[ -n "$OVERRIDE_BUMP" ]]; then
        echo "Error: multiple bump types specified ('$OVERRIDE_BUMP' and '$1')." >&2
        exit 1
      fi
      OVERRIDE_BUMP="$1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'." >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$EXPLICIT_VERSION" && -n "$OVERRIDE_BUMP" ]]; then
  echo "Error: cannot combine --version with '$OVERRIDE_BUMP'." >&2
  exit 1
fi

SEMVER_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
if [[ -n "$EXPLICIT_VERSION" && ! "$EXPLICIT_VERSION" =~ $SEMVER_REGEX ]]; then
  echo "Error: invalid SemVer '$EXPLICIT_VERSION' (expected X.Y.Z or X.Y.Z-prerelease)." >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: must be run inside a git repository." >&2
  exit 1
fi

LAST_TAG="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n 1 || true)"
if [[ -z "$LAST_TAG" ]]; then
  BASE_VERSION="0.0.0"
  LOG_RANGE="HEAD"
else
  BASE_VERSION="${LAST_TAG#v}"
  LOG_RANGE="${LAST_TAG}..HEAD"
fi

BASE_CORE="${BASE_VERSION%%-*}"
IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE_CORE"

if [[ -n "$EXPLICIT_VERSION" ]]; then
  TARGET_VERSION="$EXPLICIT_VERSION"
  BUMP_REASON="explicit --version"
else
  if [[ -n "$OVERRIDE_BUMP" ]]; then
    BUMP_TYPE="$OVERRIDE_BUMP"
    BUMP_REASON="manual override ($OVERRIDE_BUMP)"
  else
    COMMIT_COUNT="$(git rev-list --count --no-merges "$LOG_RANGE")"
    if [[ "$COMMIT_COUNT" -eq 0 ]]; then
      BUMP_TYPE="patch"
      BUMP_REASON="no non-merge commits since ${LAST_TAG:-initial} (default patch)"
    else
      COMMIT_SUBJECTS="$(git log "$LOG_RANGE" --no-merges --pretty=format:"%s")"
      COMMIT_BODIES="$(git log "$LOG_RANGE" --no-merges --pretty=format:"%b")"
      if printf '%s\n' "$COMMIT_SUBJECTS" | grep -qE '^[a-zA-Z0-9_-]+(\([^)]+\))?!:' \
        || printf '%s\n%s\n' "$COMMIT_SUBJECTS" "$COMMIT_BODIES" | grep -qE 'BREAKING[ -]CHANGE:'; then
        BUMP_TYPE="major"
        BUMP_REASON="Conventional Commits (breaking change detected in $COMMIT_COUNT commit(s))"
      elif printf '%s\n' "$COMMIT_SUBJECTS" | grep -qE '^feat(\([^)]+\))?:'; then
        BUMP_TYPE="minor"
        BUMP_REASON="Conventional Commits (feat detected in $COMMIT_COUNT commit(s))"
      else
        BUMP_TYPE="patch"
        BUMP_REASON="Conventional Commits (no feat/breaking in $COMMIT_COUNT commit(s))"
      fi
    fi
  fi

  case "$BUMP_TYPE" in
    major)
      TARGET_VERSION="$((MAJOR + 1)).0.0"
      ;;
    minor)
      TARGET_VERSION="${MAJOR}.$((MINOR + 1)).0"
      ;;
    patch)
      TARGET_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
      ;;
  esac
fi

BADGE_VERSION="${TARGET_VERSION//-/--}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

apply_transform() {
  local src="$1"
  local tmp_out="${TMP_DIR}/$(basename "$src")"

  if [[ ! -f "$src" ]]; then
    echo "Error: required file '$src' not found." >&2
    exit 1
  fi

  case "$src" in
    RPQuest.txt)
      awk -v ver="$TARGET_VERSION" '
        BEGIN { seen_ver = 0; seen_desc = 0 }
        /^## Version:/ {
          print "## Version: " ver
          seen_ver = 1
          next
        }
        /^## Description:/ {
          if ($0 ~ /\(v[0-9]+\.[0-9]+\.[0-9]+[^)]*\)/) {
            sub(/\(v[0-9]+\.[0-9]+\.[0-9]+[^)]*\)/, "(v" ver ")")
          } else {
            $0 = $0 " (v" ver ")"
          }
          print
          seen_desc = 1
          next
        }
        { print }
        END {
          if (!seen_ver || !seen_desc) exit 2
        }
      ' "$src" > "$tmp_out" || {
        echo "Error: failed to update Version/Description in '$src'." >&2
        exit 1
      }
      ;;
    src/Constants.lua)
      awk -v ver="$TARGET_VERSION" '
        BEGIN { in_meta = 0; updated = 0 }
        /^[[:space:]]*METADATA[[:space:]]*=[[:space:]]*\{/ {
          in_meta = 1
        }
        in_meta && /^[[:space:]]*VERSION[[:space:]]*=[[:space:]]*"[^"]*"/ {
          sub(/"[^"]*"/, "\"" ver "\"")
          updated = 1
        }
        in_meta && /^[[:space:]]*\},/ {
          in_meta = 0
        }
        { print }
        END {
          if (!updated) exit 2
        }
      ' "$src" > "$tmp_out" || {
        echo "Error: failed to update METADATA.VERSION in '$src'." >&2
        exit 1
      }
      ;;
    README.md|README.es.md)
      awk -v ver="$BADGE_VERSION" '
        BEGIN { updated = 0 }
        /!\[Version\]\(https:\/\/img\.shields\.io\/badge\/version-[^)]+-blue\)/ {
          sub(/badge\/version-[^)]+-blue/, "badge/version-" ver "-blue")
          updated = 1
        }
        { print }
        END {
          if (!updated) exit 2
        }
      ' "$src" > "$tmp_out" || {
        echo "Error: failed to update version badge in '$src'." >&2
        exit 1
      }
      ;;
  esac

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if cmp -s "$src" "$tmp_out"; then
      echo "UNCHANGED: $src"
    else
      echo "WOULD UPDATE: $src"
      diff -u --label "a/$src" --label "b/$src" "$src" "$tmp_out" || true
    fi
  else
    if cmp -s "$src" "$tmp_out"; then
      echo "UNCHANGED: $src"
    else
      mv "$tmp_out" "$src"
      echo "UPDATED:   $src"
    fi
  fi
}

echo "Last tag:       ${LAST_TAG:-<none>}"
echo "Target version: $TARGET_VERSION ($BUMP_REASON)"
if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Mode:           dry-run (no files modified)"
fi
echo ""

TARGET_FILES=(RPQuest.txt src/Constants.lua README.md README.es.md)
for f in "${TARGET_FILES[@]}"; do
  apply_transform "$f"
done
