#!/usr/bin/env bash
# Build the neo AppImage (static) from a st3w/neo release tag.
# Usage: build-neo.sh <neo-tag>     e.g. v0.6.1
#
# neo is a small autotools C++ program (Matrix-style terminal digital rain)
# that links against ncursesw. Release tarballs ship a pre-generated
# `configure`, so no autotools are needed at build time.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
mkdir -p "$DIST"

TAG="$1"
VER="${TAG#v}"          # v0.6.1 -> 0.6.1
BUILD="$DIST/neo-src"
SRCDIR="$BUILD/neo-$VER"

# Force baseline x86-64 (SSE2, no AVX/FMA/BMI2): GitHub's ubuntu-24.04 runner
# image is safe, but appending these flags LAST also guards against future
# image changes and any distro default. Our own code AND every static library
# compiled here stay v1-clean; prebuilt static glibc comes from Noble's
# plain x86-64-v1 archive (the workflow pins the runner for that reason).
SHIMDIR="$DIST/cc-shim"
mkdir -p "$SHIMDIR"
for c in gcc g++ cc c++; do
  if command -v "$c" >/dev/null 2>&1; then
    printf '#!/bin/sh\nexec %s "$@" -march=x86-64 -mtune=generic\n' \
      "$(command -v "$c")" > "$SHIMDIR/$c"
    chmod +x "$SHIMDIR/$c"
  fi
done
export PATH="$SHIMDIR:$PATH"

if [ ! -d "$SRCDIR" ]; then
  mkdir -p "$BUILD"
  echo "[neo] downloading neo source ($TAG)"
  curl -fsSL --retry 3 -o "$BUILD/neo-$VER.tar.gz" \
    "https://github.com/st3w/neo/releases/download/$TAG/neo-$VER.tar.gz"
  echo "[neo] extracting"
  tar xf "$BUILD/neo-$VER.tar.gz" -C "$BUILD"
fi

cd "$SRCDIR"
echo "[neo] configuring (static, ncursesw)"
# -static: fully self-contained binary. Static libncursesw.a + libtinfo.a
# come from the -dev packages on ubuntu-24.04; the LIBS order matters for
# static symbol resolution (neo's own tests only look for -lncursesw).
./configure --prefix=/usr LDFLAGS="-static" LIBS="-lncursesw -ltinfo"

echo "[neo] compiling (static)"
make -j"$(nproc)"

NEO_BIN="$SRCDIR/src/neo"
if [ ! -x "$NEO_BIN" ]; then
  NEO_BIN="$(find "$SRCDIR" -type f -name neo -perm -u+x | head -1)"
fi
if [ ! -x "$NEO_BIN" ]; then
  echo "ERROR: neo binary not found after build" >&2
  exit 1
fi
if ldd "$NEO_BIN" 2>/dev/null | grep -q "dynamic"; then
  echo "ERROR: neo is dynamically linked — AppImages in this repo must be static" >&2
  exit 1
fi
echo "[neo] built: $NEO_BIN"
file "$NEO_BIN"

# terminfo database: static ncurses still reads /usr/share/terminfo at
# RUNTIME, which minimal systems may not ship. Stage it for the packager
# (it lands inside the AppImage and AppRun points TERMINFO at the copy).
if [ -d /usr/share/terminfo ]; then
  rm -rf "$DIST/terminfo"
  cp -rL /usr/share/terminfo "$DIST/terminfo"
fi

echo "[neo] packaging AppImage"
APP_VERSION="$VER" bash "$REPO_DIR/build/package-appimage.sh" \
  neo "$NEO_BIN" \
  "Matrix-style digital rain for the terminal (CMatrix clone)" \
  "https://github.com/st3w/neo" \
  "neo-x86_64.AppImage"

echo "$VER" > "$DIST/neo.version"
echo "[neo] done (v$VER)"
