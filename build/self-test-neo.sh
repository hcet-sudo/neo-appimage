#!/usr/bin/env bash
# Self-test for the neo AppImage:
#   1) --version prints the neo banner and exits 0 (no curses needed)
#   2) --help prints the usage text and exits 0
#   3) render test: run neo in a pseudo-tty for a few seconds and require
#      ANSI escape output — proves curses initialization and the draw loop
#      actually ran (the strongest non-interactive check a curses app allows)
# Usage: self-test-neo.sh <neo-appimage-or-inner-binary-path>
#
# Every captured invocation prints its rc and output BEFORE assertions, so
# a failure in CI shows the actual error instead of dying silently.
set -euo pipefail

NEO_APP="$(readlink -f "$1")"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# EMU_PREFIX (optional): see self-test-chdman.sh — command prefix for every
# invocation, e.g. "qemu-x86_64-static -cpu qemu64" to run on an emulated
# baseline x86-64-v1 CPU. Pass the extracted inner binary as $1 when using
# this (nested execs would otherwise escape the emulator).
PREFIX=""
if [ -n "${EMU_PREFIX:-}" ]; then
  PREFIX="$EMU_PREFIX"
fi

# Probe: extract the AppImage (if it is one) so we can retry with the inner
# binary directly when the extract-and-run path fails — that separates
# runtime/AppRun problems from binary problems in one run.
EXTRACTED=""
echo "--- extraction probe ---"
if ( cd "$T" && "$NEO_APP" --appimage-extract >/dev/null 2>&1 ) \
     && [ -x "$T/squashfs-root/usr/bin/neo" ]; then
  EXTRACTED="$T/squashfs-root/usr/bin/neo"
  echo "extracted OK: $(ls -la "$T/squashfs-root/usr/bin/neo")"
else
  echo "not an AppImage (or extraction unavailable) — using the given path"
fi

echo "--- version ---"
set +e
V="$(APPIMAGE_EXTRACT_AND_RUN=1 $PREFIX "$NEO_APP" --version 2>&1 | head -3)"
rc=$?
set -e
echo "$V"
if [ "$rc" != 0 ]; then
  echo "--version exited rc=$rc (output above)" >&2
  if [ -n "$EXTRACTED" ]; then
    echo "--- retry with the extracted inner binary ---"
    set +e
    "$EXTRACTED" --version 2>&1
    echo "inner rc=$?"
    set -e
  fi
  exit 1
fi
case "$V" in
  neo\ *) : ;;
  *) echo "unexpected --version output (expected 'neo <version>')" >&2; exit 1 ;;
esac

echo "--- help ---"
set +e
H="$(APPIMAGE_EXTRACT_AND_RUN=1 $PREFIX "$NEO_APP" --help 2>&1 | head -3)"
rc=$?
set -e
echo "$H"
if [ "$rc" != 0 ]; then
  echo "--help exited rc=$rc (output above)" >&2
  exit 1
fi
if ! echo "$H" | grep -q "^Usage: neo"; then
  echo "usage text missing from --help output" >&2
  exit 1
fi

echo "--- render test (pty, ~3 s) ---"
export TERM="${TERM:-xterm-256color}"
set +e
timeout 4 script -qec "APPIMAGE_EXTRACT_AND_RUN=1 $PREFIX $NEO_APP -f 30" "$T/out.raw"
rc=$?
set -e
# 124/143: timeout killed the animation — expected for an endless program.
if [ "$rc" != 124 ] && [ "$rc" != 0 ] && [ "$rc" != 143 ]; then
  echo "neo exited unexpectedly inside the pty (rc=$rc)" >&2
  exit 1
fi
bytes="$(wc -c < "$T/out.raw")"
if [ "$bytes" -lt 500 ]; then
  echo "render test produced only $bytes bytes — nothing drawn?" >&2
  exit 1
fi
if ! LC_ALL=C grep -q $'\033\[' "$T/out.raw"; then
  echo "no ANSI escape sequences in output — curses did not render" >&2
  exit 1
fi
echo "render: $bytes bytes of ANSI output — curses draw loop OK"

echo "NEO SELF-TEST PASSED"
