#!/usr/bin/env bash
# Package a static CLI binary as a minimal AppImage using appimagetool.
# Usage: package-appimage.sh <name> <binary> <summary> <homepage> <output-appimage>
#
# Env overrides:
#   APPIMAGETOOL   path to an existing appimagetool binary (downloaded otherwise)
#   SKIP_DOWNLOAD  set non-empty to fail instead of downloading appimagetool
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
mkdir -p "$DIST"

NAME="$1"
BIN="$(readlink -f "$2")"
SUMMARY="$3"
HOMEPAGE="$4"
OUT="$DIST/$5"
METAINFO_ID="${METAINFO_ID:-io.github.neo-appimage.$NAME}"

APPDIR="$DIST/${NAME}.AppDir"
TOOL="${APPIMAGETOOL:-$DIST/appimagetool-x86_64.AppImage}"

if [ ! -x "$TOOL" ]; then
  if [ -n "${SKIP_DOWNLOAD:-}" ]; then
    echo "appimagetool not found at $TOOL" >&2
    exit 1
  fi
  echo "[pkg] downloading appimagetool"
  curl -fsSL --retry 3 -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
  chmod +x "$TOOL"
fi

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/metainfo" \
         "$APPDIR/usr/share/icons/hicolor/256x256/apps"

install -m 755 "$BIN" "$APPDIR/usr/bin/$NAME"
install -m 644 "$REPO_DIR/assets/icons/$NAME.png" "$APPDIR/$NAME.png"
install -m 644 "$REPO_DIR/assets/icons/$NAME.png" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/$NAME.png"
ln -sf "$NAME.png" "$APPDIR/.DirIcon"

# Ship the terminfo database when the build script staged one ($DIST/terminfo):
# static ncurses reads it at runtime, and minimal systems may lack it.
# AppRun points TERMINFO at the bundled copy.
if [ -d "$DIST/terminfo" ]; then
  mkdir -p "$APPDIR/usr/share"
  rm -rf "$APPDIR/usr/share/terminfo"
  cp -r "$DIST/terminfo" "$APPDIR/usr/share/terminfo"
fi

cat > "$APPDIR/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
GenericName=$SUMMARY
Exec=$NAME
Icon=$NAME
Terminal=true
Categories=Utility;ConsoleOnly;
EOF
install -m 644 "$APPDIR/$NAME.desktop" \
  "$APPDIR/usr/share/applications/$NAME.desktop"

# Per-app metadata (this copy packages neo)
DESCRIPTION='<p>
      neo is a terminal program that recreates the &quot;digital rain&quot;
      effect from The Matrix — a CMatrix clone with 32-bit color and Unicode
      support, written by Stewart Reive (st3w/neo).
    </p>
    <p>
      This is an unofficial, fully static build: it links libstdc++ and
      ncurses statically and ships its own terminfo database, so it runs on
      any x86_64 Linux without system libraries — including minimal
      containers and distros without FUSE. It is not affiliated with
      &quot;The Matrix&quot;, Warner Bros. Entertainment Inc. or Village
      Roadshow Pictures.
    </p>'
RELEASE_DATE="${RELEASE_DATE:-$(date -u +%F)}"
RELEASES_XML=""
if [ -n "${APP_VERSION:-}" ]; then
  RELEASES_XML="  <releases>
    <release version=\"${APP_VERSION}\" date=\"${RELEASE_DATE}\"/>
  </releases>"
fi

cat > "$APPDIR/usr/share/metainfo/$METAINFO_ID.appdata.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<component type="console-application">
  <id>$METAINFO_ID</id>
  <name>$NAME</name>
  <summary>$SUMMARY</summary>
  <metadata_license>MIT</metadata_license>
  <project_license>GPL-3.0-or-later</project_license>
  <description>
$DESCRIPTION
  </description>
  <launchable type="desktop-id">$NAME.desktop</launchable>
  <url type="homepage">$HOMEPAGE</url>
  <provides>
    <binary>$NAME</binary>
  </provides>
  <content_rating type="oars-1.1"/>
$RELEASES_XML
</component>
EOF

# AppRun execs via a PATH-searched bare name: PATH-searched exec passes
# argv[0] as the typed name, so usage/version output prints the bare
# program name, not the /tmp/.mount_... extraction path. POSIX sh —
# works in dash/bash/busybox. No `cd`: the user's relative paths must
# keep working. TERMINFO is pointed at the bundled database when present.
cat > "$APPDIR/AppRun" <<EOF
#!/bin/sh
HERE=\$(dirname "\$(readlink -f "\$0")")
[ -d "\$HERE/usr/share/terminfo" ] && TERMINFO="\$HERE/usr/share/terminfo"
export TERMINFO
PATH="\$HERE/usr/bin:\$PATH"
exec "$NAME" "\$@"
EOF
chmod 755 "$APPDIR/AppRun"

# refuse to package a dynamically linked binary (these AppImages must run anywhere)
if ldd "$BIN" 2>/dev/null | grep -q "dynamic"; then
  echo "ERROR: $BIN is dynamically linked — AppImages in this repo must be static" >&2
  exit 1
fi

cd "$DIST"
# --no-appstream: AppStream validation must never block the build. The metadata
# above is still shipped and catalog sites still index it.
APPIMAGE_EXTRACT_AND_RUN=1 ARCH=x86_64 "$TOOL" --no-appstream "$APPDIR" "$OUT"
echo "[pkg] OK: $OUT"
