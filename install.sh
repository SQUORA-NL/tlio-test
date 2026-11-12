#!/usr/bin/env bash
# Installs the tlio-test binary and prints the folder it was put in.
#
#   install.sh [version] [destination]
#
#   version      e.g. 1.0.0 (default: the latest release)
#   destination  folder to put the binary in (default: $RUNNER_TEMP, or a new temp folder)
#
# Environment:
#   TLIO_TEST_REPO      GitHub repository that holds the releases (default SQUORA-NL/tlio-test)
#   TLIO_TEST_TOKEN     a token with read access, only if you mirror the releases privately
#   TLIO_TEST_BASE_URL  download the archive and its .sha256 from this folder URL instead
#                       (an internal mirror, or a local test server)
#
# Works on Linux, macOS and Windows (Git Bash), which is what the hosted
# GitHub Actions and Azure DevOps agents have.
set -euo pipefail

version="${1:-latest}"
repo="${TLIO_TEST_REPO:-SQUORA-NL/tlio-test}"
dest="${2:-${RUNNER_TEMP:-$(mktemp -d)}/tlio-test-bin}"
mkdir -p "$dest"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)            rid=linux-x64;  ext=tar.gz ;;
  Darwin-arm64)            rid=osx-arm64;  ext=tar.gz ;;
  MINGW*|MSYS*|CYGWIN*)    rid=win-x64;    ext=zip ;;
  *) echo "tlio-test: no build for $(uname -s) $(uname -m). Supported: linux-x64, osx-arm64, win-x64." >&2; exit 1 ;;
esac

asset="tlio-test-${rid}.${ext}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() { # fetch <asset-name>
  if [ -n "${TLIO_TEST_BASE_URL:-}" ]; then
    curl -fsSL -o "$work/$1" "${TLIO_TEST_BASE_URL%/}/$1"
  elif [ -n "${TLIO_TEST_TOKEN:-}" ] && command -v gh >/dev/null 2>&1; then
    local tag_args=()
    [ "$version" != "latest" ] && tag_args=("v${version}")
    GH_TOKEN="$TLIO_TEST_TOKEN" gh release download "${tag_args[@]}" --repo "$repo" --pattern "$1" --dir "$work"
  elif [ "$version" = "latest" ]; then
    curl -fsSL -o "$work/$1" "https://github.com/${repo}/releases/latest/download/$1"
  else
    curl -fsSL -o "$work/$1" "https://github.com/${repo}/releases/download/v${version}/$1"
  fi
}

echo "tlio-test: downloading ${asset} (${version}) from ${repo}" >&2
fetch "$asset"
fetch "${asset}.sha256"

# Verify the download against the published checksum.
expected="$(cut -d' ' -f1 "$work/${asset}.sha256")"
if command -v sha256sum >/dev/null 2>&1; then actual="$(sha256sum "$work/$asset" | cut -d' ' -f1)"
else actual="$(shasum -a 256 "$work/$asset" | cut -d' ' -f1)"; fi
if [ "$expected" != "$actual" ]; then
  echo "tlio-test: checksum mismatch for ${asset}; refusing to install it." >&2
  exit 1
fi

if [ "$ext" = "zip" ]; then unzip -q -o "$work/$asset" -d "$dest"; else tar -xzf "$work/$asset" -C "$dest"; fi
chmod +x "$dest"/tlio-test* 2>/dev/null || true

echo "$dest"
