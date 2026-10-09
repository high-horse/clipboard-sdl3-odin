# Building on Linux

[README](../README.md) · [SDL3 setup](INSTALL-SDL3.md) · [Troubleshooting](TROUBLESHOOTING.md)

Run project commands from the directory containing `main.odin` and `Makefile`.
Build as your normal user. Running the app requires a logged-in graphical desktop
session with `XDG_RUNTIME_DIR` and either `WAYLAND_DISPLAY` or `DISPLAY` set.

## 1. Install Odin

Use a recent compiler release containing `vendor:sdl3` and `vendor:sdl3/ttf`.
The project does not pin a minimum Odin version. Follow the official
[Odin installation guide](https://odin-lang.org/docs/install/); keep the compiler's
`base`, `core`, and `vendor` collections with it, or configure `ODIN_ROOT`.
Linux linking also requires Clang.

```sh
odin version
odin root
clang --version
```

## 2. Install app dependencies

Choose the commands for your distribution. These install the toolchain, SQLite,
X11 library, clipboard helpers, and GTK3. SDL3 installation is the next step.
Python 3.9 or newer is required by the packaging helper invoked by Make.

### Debian, Ubuntu, Mint, Pop!_OS, Raspberry Pi OS

```sh
sudo apt update
sudo apt install build-essential clang make python3 pkg-config binutils \
  libsqlite3-dev libx11-dev libgtk-3-dev wl-clipboard xclip
```

### Fedora and Enterprise Linux

```sh
sudo dnf install gcc gcc-c++ clang make python3 pkgconf-pkg-config binutils \
  sqlite-devel libX11-devel gtk3 wl-clipboard xclip
```

Enterprise Linux package availability depends on the release and supported
supplemental repositories. Install missing dependencies from repositories
intended for that release.

### Arch, CachyOS, EndeavourOS, Manjaro

```sh
sudo pacman -Syu --needed base-devel clang python pkgconf binutils \
  sqlite libx11 gtk3 wl-clipboard xclip
```

### openSUSE

```sh
sudo zypper install gcc gcc-c++ clang make python3 pkg-config binutils \
  sqlite3-devel libX11-devel libgtk-3-0 wl-clipboard xclip
```

### Alpine

```sh
sudo apk add build-base clang make python3 pkgconf binutils \
  sqlite-dev libx11-dev gtk+3.0 wl-clipboard xclip
```

Use your release's matching community repository where needed. Run without
`sudo` if logged in as root. Build the app against Alpine's musl libraries;
a glibc binary from another distribution is not interchangeable.

### Gentoo and NixOS

On Gentoo, install a C toolchain, Clang, GNU Make, Python, pkg-config, SQLite,
libX11, GTK3, `wl-clipboard`, and `xclip` using Portage. See the
[SDL3 guide](INSTALL-SDL3.md#gentoo) for the SDL packages.

NixOS needs a development shell with explicit native library paths. Use the
[NixOS setup](INSTALL-SDL3.md#nixos) instead of a conventional `/usr/local` install.

Both clipboard helpers are listed for convenience: the active Wayland backend
uses `wl-copy`/`wl-paste`, and X11 uses `xclip`. libX11 is a build dependency even
when you use Wayland. GTK3 enables the native tray; a desktop tray host is also
needed. Noto fonts are already in this repository, and no SDL3_image package is
required.

## 3. Install SDL3 and SDL3_ttf

Follow [Installing SDL3](INSTALL-SDL3.md), then return here. APT-based systems use
an upstream source build; other distributions can use their native packages.
Odin's bindings do not supply these libraries.

```sh
pkg-config --modversion sdl3 sdl3-ttf
```

Both should report a version beginning with `3.`. Successful pkg-config checks
confirm development metadata, not that the runtime loader is configured; the
SDL3 guide covers both.

## 4. Build and launch

```sh
make build
./bin/clipboard-manager
```

The output is `bin/clipboard-manager`, with `bin/noto_sans_collection/` beside
it. The app resolves fonts relative to the executable, so launching from another
working directory works, but moving the binary alone does not.

To launch in the tray:

```sh
./bin/clipboard-manager --background
```

If no tray backend can be created, the app shows its window instead. Launching
another instance normally opens the existing instance's window.

### Custom compiler or library prefix

```sh
make build ODIN=/path/to/odin
make build ODIN_FLAGS='-o:speed -extra-linker-flags:-L/usr/local/lib'
```

The second command helps when the linker does not search `/usr/local/lib`.
Runtime library discovery still needs to be configured separately. Build
commands already select the system/shared SQLite binding options.

## 5. Install or package

For package-manager installation, follow [Packaging](../packaging/README.md).
For a manual install, stage the files first:

```sh
make install PREFIX=/usr/local DESTDIR="$PWD/bin/manual-install"
sudo cp -a bin/manual-install/usr/local/. /usr/local/
```

Then run `clipboard-manager` or open **Clipboard Manager** from the application
menu. This manual installation has no package-manager uninstall tracking.
The installed launcher points to the executable and bundled fonts under
`/usr/local/lib/sdl3-clipboard-manager/`.

## Checks and cleanup

```sh
make check
make test
make clean
```

`make test` runs the application and tray-backend tests, writing executables to
`bin/tests/`. `make clean` removes generated `bin/` contents, preserving
`.gitkeep`. It does not delete saved clipboard history or the old `dist/` bundle.
