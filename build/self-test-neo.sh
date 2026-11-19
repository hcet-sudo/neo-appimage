#!/usr/bin/env bash
# Self-test for the neo AppImage:
#   1) --version prints the neo banner and exits 0 (no curses needed)
#   2) --help prints the usage text and exits 0
#   3) render test: run neo in a pseudo-tty for a few seconds and require
#      ANSI escape output — proves curses initialization and the draw loop
#      actually ran (the strongest non-interactive check a curses app allows)
# Usage: self-test-neo.sh <neo-appimage-or-inner-binary-path>
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

echo "--- version ---"
V="$(APPIMAGE_EXTRACT_AND_RUN=1 $PREFIX "$NEO_APP" --version 2>&1 | head -1)"
echo "$V"
case "$V" in
  neo\ *) : ;;
  *) echo "unexpected --version output: '$V'" >&2; exit 1 ;;
esac

echo "--- help ---"
APPIMAGE_EXTRACT_AND_RUN=1 $PREFIX "$NEO_APP" --help 2>&1 | grep -q "^Usage: neo" \
  || { echo "usage text missing from --help output" >&2; exit 1; }
echo "Usage: neo ... OK"

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
