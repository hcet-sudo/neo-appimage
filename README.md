# neo — unofficial static AppImage

[![Build and release](https://github.com/hcet-sudo/neo-appimage/actions/workflows/release.yml/badge.svg)](https://github.com/hcet-sudo/neo-appimage/actions/workflows/release.yml)

<img width="594" height="411" alt="neo_is_awesome" src="https://github.com/user-attachments/assets/700ceea6-9556-4232-b135-a6e5b6d63090" />

Unofficial, **fully static** AppImage of [neo](https://github.com/st3w/neo) —
Stewart Reive's terminal recreation of the *Matrix* "digital rain" (a CMatrix
clone with 32-bit color and Unicode support) — for x86_64 Linux. Static means
no glibc, no libstdc++, no libncurses and no terminfo requirements: the
terminfo database ships inside the image, so it runs on any distribution,
however old or new, including minimal containers and distros without FUSE.

neo is licensed GPL-3; this repo only packages it. Companion repos by the
same author: [chdman-appimage](https://github.com/hcet-sudo/chdman-appimage)
and [unecm-appimage](https://github.com/hcet-sudo/unecm-appimage).

> ⚠️ Fast-moving graphics can trigger photosensitive epilepsy in susceptible
> people — the upstream project carries the same warning.

## Install

### With am / appman

```
am -e https://github.com/hcet-sudo/neo-appimage neo neo
```

### Direct download (stable URL)

```
curl -LO https://github.com/hcet-sudo/neo-appimage/releases/latest/download/neo-x86_64.AppImage
chmod +x neo-x86_64.AppImage
```

Without FUSE, run `./neo-x86_64.AppImage --appimage-extract-and-run ...`.

## Usage

```
./neo-x86_64.AppImage                     # the rain, full speed
./neo-x86_64.AppImage -m "Wake up..."     # center-screen message
./neo-x86_64.AppImage -f 30               # cap the frame rate (CPU-friendly)
./neo-x86_64.AppImage -D                  # keep your terminal's background
```

Quit with **q**. All options (colors, density, glitch effects, character
sets): `./neo-x86_64.AppImage --help`.

## How releases work (pkgforge-style)

The GitHub Actions workflow (`.github/workflows/release.yml`) runs every
Monday and on demand, then:

1. Resolves the latest neo release tag via the authenticated GitHub API.
2. Builds neo **statically** from that tag's source tarball (autotools,
   `libncursesw` + `libtinfo` linked as `.a`; cc-shim pins `-march=x86-64`).
3. **Self-tests it** — `--version` banner, `--help` usage, then a real render
   test: neo runs in a pseudo-tty for a few seconds and must produce ANSI
   output, proving curses initialization and the draw loop actually work.
4. **ISA-gates it** — the release only publishes if the same tests also pass
   under `qemu` emulating a **baseline x86-64-v1** CPU. Any v2+ instruction
   (from our code or from prebuilt static glibc) dies with SIGILL there and
   blocks the release — so the AppImage runs on every x86_64 CPU, however old.
5. Publishes a release tagged `<ver>@<date>_<epoch>` (e.g.
   `0.6.1@2026-11-19_1795...`) with the stable asset name `neo-x86_64.AppImage`,
   so `releases/latest/download/...` always points at the newest build.

Manual runs: **Actions → Build and release → Run workflow** (optionally pin a
tag, e.g. `v0.6.1`). Pushes that touch `build/` or the workflow also rebuild.

## Building locally

```
sudo apt-get install -y g++ make libncurses-dev file python3
bash build/build-neo.sh v0.6.1                     # downloads + compiles + packages
bash build/self-test-neo.sh dist/neo-x86_64.AppImage
```

The recipe configures autotools with `LDFLAGS="-static"` and
`LIBS="-lncursesw -ltinfo"` and stages `/usr/share/terminfo` for bundling —
see `build/build-neo.sh` for details.

## License

- neo itself is **GNU GPL v3 or later** (upstream `COPYING`), © Stewart
  Reive. This repository does not modify neo's sources.
- Build scripts and icons in this repo: GPL-2.0-or-later, same as the
  sibling repos.
- This is an unofficial build; file neo bugs upstream at
  [st3w/neo](https://github.com/st3w/neo), and build issues here.
- Not affiliated with "The Matrix", Warner Bros. Entertainment Inc. or
  Village Roadshow Pictures.
