# Building and running the clipboard manager on Linux

This directory contains an Odin desktop clipboard manager using SDL3. Run the
commands below from the project directory containing `main.odin` unless a step says otherwise. Use a terminal
inside your logged-in graphical desktop session; run the application as your
normal user.

For system-wide SDL dependencies, see [Installing SDL3 globally on Linux](docs/INSTALL-SDL3.md).
It covers the major distribution families, SDL3_ttf, verification, and a global
source-build fallback for releases without suitable packages.

Build into `bin/` with `make build`, or create distro packages with `make package`.
See [packaging instructions and Makefile targets](packaging/README.md) for DEB,
RPM, Arch, and tarball builds.

## Dependencies found in the source

| Dependency | Required for | Evidence / notes |
| --- | --- | --- |
| Odin compiler, including its `base`, `core`, and `vendor` collections | Build | All `.odin` files; the repository does not pin an Odin version. Use a recent release with `vendor:sdl3` and `vendor:sdl3/ttf`. |
| Clang, system linker, C runtime development files | Build | Linux native linking through the Odin toolchain. |
| SDL **3** development and runtime libraries | Build and run | `main.odin`, `watcher.odin`, and `clipboard/`; SDL2 is not a substitute. |
| SDL3_ttf development and runtime libraries | Build and run | `main.odin` imports `vendor:sdl3/ttf`. SDL2_ttf is not a substitute. |
| SQLite 3 development and runtime libraries | Build and run | Local bindings in `sqlite3/sqlite.odin`; use the system/shared-library flags shown below. No database server is required. |
| X11 / libX11 development and runtime libraries | Build and run | `clipboard/x11.odin` imports `vendor:x11/xlib` unconditionally, including in Wayland builds. |
| `wl-clipboard` (`wl-copy`, `wl-paste`) | Wayland runtime | `clipboard/wayland.odin` launches these programs. |
| `xclip` | X11 runtime | `clipboard/x11.odin` launches this program. |
| Liberation Sans Regular font | Runtime | `main.odin` opens a hard-coded font path; see the font step below. |
| Working X11 or Wayland desktop, graphics drivers | Runtime | SDL video/rendering and access to the session clipboard. |
| GTK3 and Ayatana AppIndicator3 (or AppIndicator3), desktop tray host | Optional tray runtime | SDL's Linux tray backend loads these libraries dynamically. COSMIC provides a status area; other desktops need compatible tray support. Without tray support the normal window remains usable. |
| Writable application data directory | Runtime | SQLite, configuration, and clipboard blobs are created there. |
| `pkg-config` / `pkgconf`, Fontconfig tools | Setup checks | Used by this guide to inspect libraries and locate fonts; the application does not invoke them. |

The Odin imports under `core:` and `base:` are supplied with Odin. The local
`clipboard` and `sqlite3` packages are already in this repository. Odin's vendor
bindings do not replace the Linux native libraries listed above. SDL3_ttf's
transitive dependencies (such as FreeType and HarfBuzz) are handled by the package
manager. There is no separate PNG/JPEG decoder dependency: this code stores those
clipboard payloads as bytes and displays a text label.

Optional: Git to obtain sources, CMake and Make/Ninja to build native libraries
from source, and the `sqlite3` CLI to inspect stored data. OLS is an optional
editor language server (`ols.json`), not a build requirement. SQLCipher is an
optional binding configuration and is disabled by default; it is not required.

## 1. Install native packages

Choose your distribution family. These commands include **both** clipboard
backends for convenience; only your active backend's command-line helper is
required. Development packages also pull in their runtime libraries.

Package availability depends on your distribution release and enabled
repositories. Check the search commands before installing SDL3. In particular,
older LTS releases may have SDL2 but no SDL3/SDL3_ttf. Do not mix packages from a
different distribution release; use the source-build fallback instead.

### Debian, Ubuntu, Linux Mint, Pop!_OS

```sh
sudo apt update
apt-cache policy libsdl3-dev libsdl3-ttf-dev
sudo apt install build-essential clang pkg-config fontconfig \
  libsqlite3-dev libx11-dev wl-clipboard xclip fonts-liberation
# Run this only if both SDL3 packages have an installation candidate:
sudo apt install libsdl3-dev libsdl3-ttf-dev
```

Ubuntu's SDL3_ttf development package is in Universe on releases that provide it;
see the [Ubuntu package listing](https://packages.ubuntu.com/questing/libsdl3-ttf-dev).
Ubuntu 24.04-based systems may need the source-build fallback.

### Fedora; RHEL, Rocky Linux, AlmaLinux, CentOS Stream

```sh
dnf search SDL3
sudo dnf install gcc gcc-c++ clang make pkgconf-pkg-config fontconfig \
  sqlite-devel libX11-devel wl-clipboard xclip liberation-sans-fonts
# Requires repositories that provide these packages for your release:
sudo dnf install SDL3-devel SDL3_ttf-devel
```

[Fedora packages SDL3_ttf-devel](https://packages.fedoraproject.org/pkgs/SDL3_ttf/).
Enterprise Linux repositories can lack SDL3 or the clipboard tools. Check your
release's supported supplemental repositories (for example EPEL/CRB) or build
missing components from upstream; Fedora RPMs are not an EL installation method.

### Arch Linux, EndeavourOS, Manjaro

```sh
sudo pacman -Syu --needed base-devel clang pkgconf fontconfig \
  sdl3 sdl3_ttf sqlite libx11 wl-clipboard xclip ttf-liberation
```

Arch includes development files in the library packages. See its
[SDL3_ttf package](https://archlinux.org/packages/extra/x86_64/sdl3_ttf/).

### openSUSE Tumbleweed / Leap

```sh
zypper search -s SDL3
sudo zypper install gcc gcc-c++ clang make pkg-config fontconfig \
  sqlite3-devel libX11-devel wl-clipboard xclip liberation-fonts
# If available for your release:
sudo zypper install SDL3-devel SDL3_ttf-devel
```

Availability varies by Leap release and repositories. The
[openSUSE Games repository listing](https://download.opensuse.org/download/repositories/games/16.0/x86_64/)
is a reference for package availability; use the fallback if your release lacks it.

### Alpine Linux

Run as root, or prefix with `doas` if configured:

```sh
apk search sdl3
apk add build-base clang pkgconf fontconfig sqlite-dev libx11-dev \
  wl-clipboard xclip font-liberation
apk add sdl3-dev sdl3_ttf-dev
```

SDL3 packages require a branch/repository that provides them; see the
[Alpine package listing](https://pkgs.alpinelinux.org/package/edge/community/x86/sdl3_ttf).
Do not mix stable and edge packages just to satisfy this list. Alpine uses musl:
an upstream Odin binary built for glibc may not run. Obtain a compatible Odin
package or build Odin for the host using the upstream compiler instructions.

### Gentoo

```sh
sudo emerge --ask llvm-core/clang dev-util/pkgconf media-libs/fontconfig \
  media-libs/libsdl3 media-libs/sdl3-ttf dev-db/sqlite x11-libs/libX11 \
  gui-apps/wl-clipboard x11-misc/xclip media-fonts/liberation-fonts
```

The current [Clang package is llvm-core/clang](https://packages.gentoo.org/packages/llvm-core/clang).
Ensure SDL's USE flags enable your X11/Wayland video backend.
The standard Gentoo compiler/linker toolchain is also needed. Check the
[Gentoo SDL3_ttf package](https://packages.gentoo.org/packages/media-libs/sdl3-ttf)
for architecture and keyword availability.

### NixOS / Nix development shell

Use a nixpkgs revision providing Odin and SDL3_ttf. A development shell is more
appropriate than expecting libraries in `/usr/lib`. Save this as `shell.nix` if
you use Nix (it is an optional example, not a repository build file):

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ odin clang pkg-config fontconfig ];
  buildInputs = with pkgs; [ sdl3 sdl3-ttf sqlite xorg.libX11 ];
  packages = with pkgs; [ wl-clipboard xclip liberation_ttf ];
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
    sdl3 sdl3-ttf sqlite xorg.libX11
  ]);
  shellHook = ''
    export CLIPBOARD_FONT_DIR="${pkgs.liberation_ttf}/share/fonts"
  '';
}
```

Enter with `nix-shell`, then perform the font and build steps in that shell.
Nixpkgs attribute names can change; adjust them to your selected revision.
Locate the font with `find "$CLIPBOARD_FONT_DIR" -name LiberationSans-Regular.ttf`
and update `main.odin` as described below. A shell still needs access to your
host desktop session and graphics drivers.

## 2. Install and check Odin

Follow the [official Odin installation instructions](https://odin-lang.org/docs/install/)
or use your distribution's Odin package. For the upstream release route:

1. Download the Linux archive for your CPU architecture from the linked releases.
2. Extract the **entire** archive, for example into `$HOME/.local/opt/odin`.
3. Add the directory containing the `odin` executable to your shell's `PATH`.
   Keep `base`, `core`, and `vendor` next to the executable, or configure
   `ODIN_ROOT` as documented upstream.

```sh
# Adjust this to the directory where you extracted the compiler:
export PATH="$HOME/.local/opt/odin:$PATH"
odin version
odin root
clang --version
```

Persist the PATH setting in your shell configuration if needed. Compiler source
builds additionally require the LLVM version supported by that Odin checkout;
follow its instructions rather than installing an arbitrary LLVM version.
The project has no pinned or verified minimum compiler version.

## 3. If SDL3 packages are unavailable: build the libraries

Skip this section when both SDL3 development packages are installed. Install Git,
CMake, a C/C++ compiler, Make, FreeType and HarfBuzz development packages, and the
development libraries for your desktop backend. Consult SDL's
[Linux build dependencies](https://wiki.libsdl.org/SDL3/README-linux) and
[SDL_ttf build instructions](https://github.com/libsdl-org/SDL_ttf/blob/main/INSTALL.md).

For Ubuntu/Debian systems missing SDL3 packages, the following supplements step 1
with common desktop build dependencies:

```sh
sudo apt install git cmake libfreetype-dev libharfbuzz-dev \
  libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev libdecor-0-dev \
  libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libdrm-dev libgbm-dev
```

Download and extract stable **SDL3** and **SDL3_ttf** source releases from
[SDL releases](https://github.com/libsdl-org/SDL/releases) and
[SDL_ttf releases](https://github.com/libsdl-org/SDL_ttf/releases).
Use an SDL version meeting the selected SDL_ttf release's minimum requirement.
Run the following from the directory containing the extracted sources, replacing
the two source directory placeholders with their actual names:

```sh
export CLIPBOARD_DEPS_PREFIX="$HOME/.local/opt/clipboard-deps"
cmake -S /path/to/SDL3-source -B build-sdl3 \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$CLIPBOARD_DEPS_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib -DSDL_SHARED=ON -DSDL_STATIC=OFF
cmake --build build-sdl3 --parallel
cmake --install build-sdl3

cmake -S /path/to/SDL3_ttf-source -B build-sdl3-ttf \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$CLIPBOARD_DEPS_PREFIX" \
  -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_PREFIX_PATH="$CLIPBOARD_DEPS_PREFIX" \
  -DBUILD_SHARED_LIBS=ON -DSDLTTF_VENDORED=OFF
cmake --build build-sdl3-ttf --parallel
cmake --install build-sdl3-ttf

export PKG_CONFIG_PATH="$CLIPBOARD_DEPS_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LIBRARY_PATH="$CLIPBOARD_DEPS_PREFIX/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="$CLIPBOARD_DEPS_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
```

Inspect the SDL CMake summary: your intended X11/Wayland video backend must be
enabled. Resolve missing required dependencies reported by CMake. The exports
apply only to this shell; repeat them in future build/run sessions. If Odin's
linker still cannot locate these libraries, add
`-extra-linker-flags:"-L$CLIPBOARD_DEPS_PREFIX/lib"` to the build command below.

## 4. Check the font path

The application currently opens exactly:

```text
/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf
```

Installing the font does not guarantee this path exists. Check it:

```sh
test -r /usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf \
  && echo 'Font path OK' || echo 'Font path needs updating in main.odin'
fc-match -f '%{file}\n' 'Liberation Sans:style=Regular'
```

If the hard-coded path is absent, locate the installed font (common alternatives
include `/usr/share/fonts/liberation/` and
`/usr/share/fonts/truetype/liberation2/`). Replace the first argument of
`ttf.OpenFont` in `main.odin` with the actual readable font filename and rebuild.
`fc-match` can return a substitute when Liberation Sans is missing, so inspect
its result. There is currently no font environment variable or command-line
option in the application. On NixOS use the font's Nix store path from step 1.

## 5. Check dependencies and the desktop session

Run these checks in the same terminal where you will build and launch:

```sh
for tool in odin clang pkg-config fc-match; do
  command -v "$tool" || printf 'MISSING tool: %s\n' "$tool"
done
for library in sdl3 sdl3-ttf sqlite3 x11; do
  if pkg-config --exists "$library"; then
    printf '%s: ' "$library"
    pkg-config --modversion "$library"
  else
    printf 'MISSING development package or pkg-config path: %s\n' "$library"
  fi
done
printf 'WAYLAND_DISPLAY=%s\nDISPLAY=%s\nXDG_RUNTIME_DIR=%s\n' \
  "${WAYLAND_DISPLAY-}" "${DISPLAY-}" "${XDG_RUNTIME_DIR-}"
if [ "${WAYLAND_DISPLAY+x}" = x ]; then
  command -v wl-copy
  command -v wl-paste
  wl-paste --list-types
elif [ "${DISPLAY+x}" = x ]; then
  command -v xclip
  xclip -selection clipboard -o -t TARGETS
else
  echo 'No desktop display environment: launch from a graphical session.'
fi
```

The SDL3_ttf pkg-config module is named `sdl3-ttf`, not `SDL3_ttf`; see the
[installed package files](https://archlinux.org/packages/extra/x86_64/sdl3_ttf/files/).
These checks report problems but do not install anything. `pkg-config` checks
development metadata; a successful link and launch are still needed.

The code selects Wayland whenever `WAYLAND_DISPLAY` **exists**, even if empty,
before considering `DISPLAY`. Its Wayland initialization does not verify helper
availability or compositor support, so a missing `wl-paste` does not trigger an
automatic X11 fallback. Copy some text in another application before checking
clipboard types; an empty clipboard can itself cause a nonzero result.

Wayland clipboard access depends on compositor protocol support and session
permissions. If the helper fails with a nonempty clipboard, resolve that error
first. If an accessible X11/XWayland display is available, explicitly try:

```sh
env -u WAYLAND_DISPLAY SDL_VIDEO_DRIVER=x11 ./clipboard-manager
```

This command is for use **after building**. Merely setting a display variable
does not create a desktop session or grant access to one.

## 6. Build and run

From the directory containing `main.odin`:

```sh
odin check . -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
odin build . -out:clipboard-manager \
  -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
ldd ./clipboard-manager
./clipboard-manager
```

Resolve any `not found` lines from `ldd` before launching. For a direct build/run:

```sh
odin run . -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
```

Both SQLite flags matter: the local binding defaults to a package-local static
`libsqlite3.a`, which is not included in this repository. The flags select the
system `libsqlite3.so`. Keep SQLCipher disabled for the normal build.

The app opens a resizable window and displays clipboard history in bordered cards.
Use **Clear all** at the top to remove clipboard history and its saved files. The
button is disabled when the list is empty; your current system clipboard is preserved.
Hover over a card to highlight it; click to copy its full contents. Scroll to browse
older items, or use Up/Down, Home/End and Enter to select and copy. Cards wrap
previews to fit the window, and show confirmation or an error after copying. A
clipboard icon in the desktop tray provides **Show Clipboard Manager**, **Hide
window**, and **Quit** actions. Closing the window or pressing Escape hides it
while clipboard monitoring continues; choose **Quit** from the tray to exit.
If tray creation fails, closing the window or pressing Escape exits instead.
On Debian/Ubuntu, tray support can be installed with
`sudo apt install libgtk-3-0t64 libayatana-appindicator3-1` (older releases may name
the GTK package `libgtk-3-0`). The tray API requires SDL 3.2 or newer; see the
[SDL tray documentation](https://wiki.libsdl.org/SDL3/SDL_CreateTray).
Starting the app preserves the current clipboard. Clipboard contents are printed
to the terminal and stored locally.

Storage is under `$XDG_DATA_HOME/sdl3-clipboard-manager` when `XDG_DATA_HOME` is
nonempty, otherwise `$HOME/.local/share/sdl3-clipboard-manager`. If HOME is also
missing, the fallback is `/tmp/.local/share/sdl3-clipboard-manager`. The app creates:

- `cd.slm`: SQLite database.
- `blobs/`: clipboard payload files.
- `cfg.jsn`: configuration, created with defaults when missing.

## Troubleshooting and verification limits

| Symptom | Check / action |
| --- | --- |
| `odin: command not found` or missing `core` / `vendor` collections | Check PATH and the complete Odin installation / `ODIN_ROOT`. |
| Missing `libsqlite3.a` | Include both SQLite flags above. |
| Cannot find SDL3, SDL3_ttf, SQLite, or X11 at link time | Install development packages, not only runtime packages; check library architecture and custom library search paths. |
| Shared library missing at launch | Inspect `ldd`; for a local prefix restore `LD_LIBRARY_PATH`. |
| `Failed to load font` | Correct the `ttf.OpenFont` path and rebuild. |
| SDL video initialization or renderer failure | Run inside a desktop session; inspect SDL's error, graphics drivers, and enabled video backends. |
| Clipboard never updates | Run the selected helper directly; check display variables, clipboard contents, and Wayland protocol support. |
| Database/configuration creation fails | Check write permission and free space in the application data directory. |
| Odin type/API errors | Record `odin version`; compiler/vendor API compatibility is separate from native-library installation. |

This guide was prepared by scanning the project imports, foreign bindings,
subprocess commands, and runtime paths. Installation commands vary by release;
they have not been executed across all listed distributions. On this Pop!_OS
24.04 machine, Odin dev-2026-09 passed `odin check` and built the application
against SDL 3.4.16, SDL3_ttf 3.2.2, and system SQLite. Launching reached the main
loop and successfully stored the startup clipboard text.

The locally built executable can currently be launched with `./clipboard-manager`.
Its SDL libraries are under `~/.local/opt/sdl3-clipboard-manager/lib`, embedded
as an absolute runtime search path for this machine. For another machine,
rebuild using the local-prefix instructions above. The local SDL build disabled the
optional X11 XTEST feature (`-DSDL_X11_XTEST=OFF`); the SDL3_ttf build disabled
optional SVG font support (`-DSDLTTF_PLUTOSVG=OFF`). There is no automated test
suite or dependency version lockfile in this directory.

### Desktop shortcut on this machine

**Clipboard Manager** is installed in the application menu and pinned to the
COSMIC dock. Its desktop entry is
`~/.local/share/applications/com.example.odinsdl3clipboardmanager.desktop`.
The installed executable and SDL libraries are in
`~/.local/opt/sdl3-clipboard-manager/`; this copy does not depend on `/tmp`.
The running app also registers a clipboard icon in COSMIC's top-bar status area.
Launch it from the dock or run:

```sh
"$HOME/.local/opt/sdl3-clipboard-manager/launch"
```

This is a copy of the current build; rebuilding the project does not automatically
update the installed copy. The original COSMIC favorites were backed up next to
the favorites file as `favorites.before-clipboard-manager`.

## Automatic startup and keyboard shortcut

The installed app starts in the tray at login through
`~/.config/autostart/com.example.odinsdl3clipboardmanager.desktop`, which runs
`~/.local/opt/sdl3-clipboard-manager/launch --background`. If tray support is
unavailable, it shows the window instead.

On this COSMIC desktop, **Super + V** (Windows key + V) runs the installed launcher
and opens the existing window. The binding is in
`~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom`; existing
shortcuts are preserved. Escape or the close button hides the window again.

A lock in `$XDG_RUNTIME_DIR/sdl3-clipboard-manager` prevents duplicate instances.
Subsequent launches forward an activation request, including the desktop's Wayland
activation token when provided, to the running app. The operating system releases
the lock when the process exits. `--background` never raises an existing window.

The installed executable is a copy of the project build. Future rebuilds need to
be installed there and the running app restarted to update the shortcut and
automatically started version. Startup, shortcut, and executable backups from
setup have a `.before-startup-<timestamp>` suffix beside the originals.

## Share an Ubuntu installer

The `dist/` directory contains:

- `sdl3-clipboard-manager_0.1.0_amd64.deb`: Ubuntu 24.04 Intel/AMD installer.
- `README-Ubuntu.md`: installation, desktop compatibility, shortcut and startup instructions.
- `SHA256SUMS`: checksum for the package.

Send the package and README to the recipient. Install with
`sudo apt install ./sdl3-clipboard-manager_0.1.0_amd64.deb` from the download folder.
SDL3 and SDL3_ttf are included; Ubuntu installs the remaining runtime dependencies.
This build requires glibc 2.38 or newer and cannot be installed on Ubuntu 22.04.
The package contains no clipboard database, saved clipboard files, or personal
configuration. Installation does not modify the recipient's shortcuts or enable
startup automatically; the included guide explains both options.

To rebuild on an Ubuntu 24.04-compatible amd64 build machine:

```sh
python3 packaging/build_deb.py \
  --odin /path/to/odin \
  --sdl-prefix /path/to/sdl-install-prefix \
  --sdl-license /path/to/SDL/LICENSE.txt \
  --ttf-license /path/to/SDL_ttf/LICENSE.txt
```

The prefix must contain shared SDL3 and SDL3_ttf libraries under `lib/`.
The compiler uses the baseline x86-64 CPU target. Packaging validates library
resolution and rejects machine-specific runtime search paths. A local apt dry run,
package extraction, headless startup and activation smoke check, and per-user
autostart enable/disable checks passed. A clean Ubuntu GNOME desktop has not yet
been tested.
