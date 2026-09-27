#!/usr/bin/env bash
# Compile src/parser.c into a platform-named shared library.
# Usage:
#   scripts/build-parser.sh [outdir]
# Env:
#   GOHTML_PLATFORM  override id, e.g. linux-x86_64 / darwin-arm64 / windows-x86_64
#   CC               compiler (default: cc)
#   CFLAGS           extra flags
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="${1:-"$ROOT/dist"}"
SRC="$ROOT/src/parser.c"

if [[ ! -f "$SRC" ]]; then
  echo "missing $SRC — run tree-sitter generate first" >&2
  exit 1
fi

uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"
uname_m="$(uname -m | tr '[:upper:]' '[:lower:]')"

case "$uname_m" in
  amd64|x64) uname_m=x86_64 ;;
  aarch64|arm64) uname_m=arm64 ;;
esac

case "$uname_s" in
  linux*) os=linux ;;
  darwin*) os=darwin ;;
  mingw*|msys*|cygwin*|windows_nt*) os=windows ;;
  *) os="$uname_s" ;;
esac

platform="${GOHTML_PLATFORM:-$os-$uname_m}"
os_part="${platform%%-*}"
arch_part="${platform#*-}"

mkdir -p "$OUTDIR"

if [[ "$os_part" == "windows" ]]; then
  ext=dll
  linkflags="-shared"
else
  ext=so
  if [[ "$os_part" == "darwin" ]]; then
    linkflags="-dynamiclib -undefined dynamic_lookup"
  else
    linkflags="-shared"
  fi
fi

asset="parser-gohtml-${platform}.${ext}"
dest="$OUTDIR/$asset"
# Neovim runtime name (copy next to the asset for local install helpers).
if [[ "$ext" == "dll" ]]; then
  runtime_name="gohtml.dll"
else
  runtime_name="gohtml.so"
fi

CC="${CC:-cc}"
# shellcheck disable=SC2086
$CC ${CFLAGS:--O2 -fPIC} -I "$ROOT/src" $linkflags -o "$dest" "$SRC"
cp "$dest" "$OUTDIR/$runtime_name"

echo "$dest"
echo "runtime copy: $OUTDIR/$runtime_name"
