# Installing SDL3 globally on Linux

This clipboard manager requires **SDL3 and SDL3_ttf**, including their shared
libraries and development files. Odin supplies bindings, not these native
libraries. SDL2 and SDL2_ttf cannot replace them. SDL3_image is not required;
the app uses Odin's bundled stb decoder for image previews.

Package-manager commands below install system-wide for all users. Prefer this
route because your distribution handles library paths and updates. Availability
depends on the release, architecture, and enabled repositories: check for both
packages before installing. If either is missing, use the source fallback below.
Do not install packages from a different distribution release to obtain SDL3.

This guide covers SDL dependencies only. See the [main README](../README.md)
for Odin, SQLite, clipboard helpers, and the remaining application requirements.

## Debian, Ubuntu, Linux Mint, Pop!_OS, Raspberry Pi OS

```sh
sudo apt update
apt-cache policy libsdl3-dev libsdl3-ttf-dev
# Continue only when both packages have a Candidate other than (none).
sudo apt install libsdl3-dev libsdl3-ttf-dev pkg-config
```

On Ubuntu, SDL3_ttf is in Universe on releases that package it. Enable Universe
if necessary, then repeat the checks:

```sh
sudo add-apt-repository universe
sudo apt update
```

The Universe command is Ubuntu-specific. Older Debian/Ubuntu releases and their
derivatives may need the source fallback even after all normal repositories are
enabled. Raspberry Pi OS availability also depends on its Debian base and CPU
architecture.

Package references: [Debian](https://packages.debian.org/search?keywords=libsdl3),
[Ubuntu](https://packages.ubuntu.com/search?keywords=libsdl3).

## Fedora

```sh
dnf info SDL3-devel SDL3_ttf-devel
sudo dnf install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
```

Both development packages pull in the corresponding runtime libraries. Older
Fedora releases may lack SDL3_ttf.

Package references: [SDL3](https://packages.fedoraproject.org/pkgs/SDL3/),
[SDL3_ttf](https://packages.fedoraproject.org/pkgs/SDL3_ttf/).

For Fedora Atomic desktops such as Silverblue/Kinoite, use host package layering
instead of `dnf`, if these packages are available in the host release:

```sh
sudo rpm-ostree install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
systemctl reboot
```

A Toolbox installation only supplies libraries inside that container; it does
not install them for a clipboard-manager binary launched on the host desktop.
See Fedora's [package layering documentation](https://docs.fedoraproject.org/en-US/fedora-silverblue/getting-started/).

## RHEL, Rocky Linux, AlmaLinux, CentOS Stream

```sh
dnf info SDL3-devel SDL3_ttf-devel
# Only if your release's enabled repositories provide both:
sudo dnf install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
```

Enterprise Linux does not necessarily ship the same packages as Fedora. Check
the supported supplemental repositories for your release (such as CRB/EPEL).
If SDL3 or SDL3_ttf is unavailable, use the source fallback; Fedora RPMs are not
a substitute for Enterprise Linux packages.

## Arch Linux, CachyOS, EndeavourOS, Manjaro

```sh
sudo pacman -Syu --needed sdl3 sdl3_ttf pkgconf
```

These packages include development files; there are no separate `-dev` packages.
Use a full system upgrade to avoid an unsupported partial upgrade. Derivatives
may receive packages later than Arch.

Package references: [sdl3](https://archlinux.org/packages/extra/x86_64/sdl3/),
[sdl3_ttf](https://archlinux.org/packages/extra/x86_64/sdl3_ttf/).

## openSUSE Tumbleweed and Leap

```sh
sudo zypper refresh
zypper search -s SDL3
# Only if both development packages are available for your release:
sudo zypper install SDL3-devel SDL3_ttf-devel pkg-config
```

Check the exact package names in the search results. Availability differs by
Leap release and repository; use the source fallback if either package is absent
from repositories supported for your release. Do not add a Tumbleweed repository
to Leap just to obtain these libraries.

Package search: [openSUSE](https://software.opensuse.org/search?q=SDL3).

## Alpine Linux

```sh
sudo apk update
apk search -x sdl3-dev
apk search -x sdl3_ttf-dev
sudo apk add sdl3-dev sdl3_ttf-dev pkgconf
```

Enable the `community` repository matching your installed Alpine release if
needed. Do not mix stable and edge repositories. Run commands without `sudo` if
already logged in as root. A binary built against glibc on another distro must
be rebuilt for Alpine's musl environment.

Package reference: [Alpine SDL3_ttf](https://pkgs.alpinelinux.org/packages?name=sdl3_ttf*).

## Gentoo

```sh
emerge --search libsdl3
emerge --search sdl3-ttf
sudo emerge --ask media-libs/libsdl3 media-libs/sdl3-ttf dev-util/pkgconf
```

Use your normal Gentoo keyword policy if a package is not stable for your
architecture. Enable the X/Wayland and rendering USE flags needed by your desktop;
review the flags offered by the selected ebuild before emerging.

Package references: [libsdl3](https://packages.gentoo.org/packages/media-libs/libsdl3),
[sdl3-ttf](https://packages.gentoo.org/packages/media-libs/sdl3-ttf).

## NixOS

Add these packages to your existing system configuration, then rebuild:

```nix
environment.systemPackages = with pkgs; [
  sdl3
  sdl3-ttf
  pkg-config
];
```

```sh
sudo nixos-rebuild switch
```

NixOS stores libraries in `/nix/store`, rather than conventional `/usr/lib`
locations. Installing packages globally alone does not make Odin's system
library imports or an externally built ELF binary find them. Build in a Nix
development shell or package the app in a derivation that supplies library
search paths and a runtime RPATH. For a development shell, save this as
`shell.nix` in the project directory:

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [ odin clang pkg-config ];
  buildInputs = with pkgs; [ sdl3 sdl3-ttf sqlite xorg.libX11 ];
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath
    (with pkgs; [ sdl3 sdl3-ttf sqlite xorg.libX11 ]);
}
```

```sh
nix-shell
odin build . -out:clipboard-manager \
  -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
./clipboard-manager
```

Run from that shell; a packaged desktop launch needs its own runtime paths and
clipboard helpers. Use a nixpkgs revision providing both SDL packages. Do not
use the `/usr/local` fallback on NixOS.

References: [NixOS package search](https://search.nixos.org/packages?query=sdl3),
[Nix development shells](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell).

## Global source fallback: `/usr/local`

Use this on conventional Linux systems when distro packages are unavailable or
too old for your Odin bindings. It installs shared libraries, headers, CMake
metadata, and pkg-config files for all users without overwriting files in `/usr`
owned by the distribution. Build as your normal user; only installation needs
root. These commands use SDL 3.4.18 and SDL3_ttf 3.2.2 as explicit release examples.

### 1. Install build dependencies

You need a C/C++ toolchain, CMake, Ninja, Git, pkg-config, FreeType and HarfBuzz
development files, plus development files for your desktop's video backend.
The following is a Debian/Ubuntu example with X11 and Wayland support:

```sh
sudo apt install build-essential cmake ninja-build git pkg-config \
  libfreetype-dev libharfbuzz-dev libx11-dev libxext-dev libxrandr-dev \
  libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev libdecor-0-dev \
  libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libdrm-dev libgbm-dev
```

On other distros install equivalent packages using their package manager. See
the upstream [Linux dependency lists](https://wiki.libsdl.org/SDL3/README-linux)
for Fedora, Arch, openSUSE, and other systems. Review CMake's dependency summary
to ensure it enables the video backend you use. Audio/controller dependencies
are optional for this clipboard application.

### 2. Build and install SDL3, then SDL3_ttf

Run the whole sequence in the same Bash-compatible shell. Keep the source and
build directories if you want installation manifests for later maintenance.
Choose a fresh working directory if these checkout directories already exist.

```sh
mkdir -p "$HOME/src/odin-clipboard-deps"
cd "$HOME/src/odin-clipboard-deps"

git clone --depth 1 --branch release-3.4.18 https://github.com/libsdl-org/SDL.git
cmake -S SDL -B SDL/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_INSTALL_LIBDIR=lib -DSDL_SHARED=ON -DSDL_STATIC=OFF \
  -DSDL_X11=ON -DSDL_WAYLAND=ON
cmake --build SDL/build --parallel
sudo cmake --install SDL/build

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

git clone --depth 1 --branch release-3.2.2 https://github.com/libsdl-org/SDL_ttf.git
cmake -S SDL_ttf -B SDL_ttf/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_PREFIX_PATH=/usr/local \
  -DBUILD_SHARED_LIBS=ON -DSDLTTF_VENDORED=OFF \
  -DSDLTTF_SAMPLES=OFF -DSDLTTF_PLUTOSVG=OFF
cmake --build SDL_ttf/build --parallel
sudo cmake --install SDL_ttf/build
```

This disables optional SVG color-glyph support to avoid an additional plutosvg
dependency. FreeType and HarfBuzz remain enabled. For an X11-only build use
`-DSDL_WAYLAND=OFF`; for Wayland-only use `-DSDL_X11=OFF`. The app itself still
requires libX11 for its compiled clipboard bindings.

Build references: [SDL CMake](https://wiki.libsdl.org/SDL3/README-cmake),
[SDL releases](https://github.com/libsdl-org/SDL/releases),
[SDL3_ttf 3.2.2 build options](https://github.com/libsdl-org/SDL_ttf/blob/release-3.2.2/CMakeLists.txt).
Newer SDL3_ttf releases may require a newer SDL3; check their CMake requirements
before changing either version.

### 3. Make shared libraries discoverable globally

On glibc-based systems, register the chosen library directory and refresh the
loader cache. This also supports launching the app from the desktop/tray without
shell-specific `LD_LIBRARY_PATH` settings:

```sh
printf '%s\n' /usr/local/lib | sudo tee /etc/ld.so.conf.d/odin-clipboard-local.conf
sudo ldconfig
```

On Alpine/musl, `ldconfig` does not provide a glibc-style cache. Ensure
`/usr/local/lib` is included in the architecture-specific
`/etc/ld-musl-<architecture>.path`, preserving all existing entries. If no file
exists, musl's default search path already includes `/usr/local/lib`.
See the [musl loader-path documentation](https://wiki.musl-libc.org/faq.html).

If your compiler cannot find the link-time libraries despite the loader setup,
pass `-extra-linker-flags:"-L/usr/local/lib"` to `odin build` and `odin check`.
For pkg-config checks in subsequent terminals, export `PKG_CONFIG_PATH` as above
if `/usr/local/lib/pkgconfig` is not in its default search path. Source installs
do not receive package-manager updates: rebuild and reinstall to update them.

## Verify and build the app

```sh
pkg-config --modversion sdl3 sdl3-ttf
pkg-config --libs sdl3 sdl3-ttf
```

Both versions should start with `3.`. If a module is missing, check that its
development package is installed and that pkg-config searches the correct
prefix. On glibc systems, also inspect the runtime loader cache:

```sh
ldconfig -p | grep -E 'libSDL3(_ttf)?\.so'
```

From the directory containing `main.odin`, after installing the other app
dependencies:

```sh
odin check . -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
odin build . -out:clipboard-manager \
  -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
ldd ./clipboard-manager
./clipboard-manager
```

Check that `ldd` reports no `not found` entries and resolves both SDL libraries
from your intended prefix. Run the app as your normal desktop user. If the Odin
bindings reference symbols absent from an older distro SDL3, install a compatible
newer SDL3 or use the source fallback.

Package names and upstream build instructions were checked against linked
sources on 2026-10-09. Commands are documentation examples, not an assertion
that every supported distro/release was tested.
