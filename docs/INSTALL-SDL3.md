# Installing SDL3 and SDL3_ttf

[README](../README.md) · [Building the app](BUILDING.md) · [Troubleshooting](TROUBLESHOOTING.md)

The app needs **both** SDL3 and SDL3_ttf shared libraries and development files.
Odin's vendor bindings do not install them. SDL2 packages cannot replace them.

Choose your distribution below. APT-based systems use an upstream source build
in this guide. Other distributions can use native packages when their release
provides both libraries. All installation methods here make libraries available
system-wide, except the explicitly scoped NixOS development shell.

## Debian, Ubuntu, Mint, Pop!_OS, Raspberry Pi OS

Use APT for build dependencies, then clone and install SDL3 and SDL3_ttf manually.
Run this first:

```sh
sudo apt update
sudo apt install build-essential git cmake ninja-build pkg-config \
  libfreetype-dev libharfbuzz-dev libx11-dev libxext-dev libxrandr-dev \
  libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev \
  libwayland-dev wayland-protocols libxkbcommon-dev libdecor-0-dev \
  libegl1-mesa-dev libgl1-mesa-dev libgles2-mesa-dev libdrm-dev libgbm-dev
```

Continue with [Source install](#source-install) below, including the runtime
library-path step. No SDL3 APT package is required by this workflow.

## Fedora

```sh
dnf info SDL3-devel SDL3_ttf-devel
sudo dnf install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
```

If your release lacks either package, use [Source install](#source-install).
Package references: [SDL3](https://packages.fedoraproject.org/pkgs/SDL3/),
[SDL3_ttf](https://packages.fedoraproject.org/pkgs/SDL3_ttf/).

Fedora Atomic desktops use host layering instead of `dnf`:

```sh
sudo rpm-ostree install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
systemctl reboot
```

Packages installed only inside Toolbox do not supply libraries for an app
launched on the host desktop.

## RHEL, Rocky Linux, AlmaLinux, CentOS Stream

```sh
dnf info SDL3-devel SDL3_ttf-devel
```

If supported repositories for your release provide both, install them:

```sh
sudo dnf install SDL3-devel SDL3_ttf-devel pkgconf-pkg-config
```

Otherwise use [Source install](#source-install). Enterprise Linux availability
is different from Fedora; do not install Fedora RPMs or mix distribution releases.

## Arch, CachyOS, EndeavourOS, Manjaro

```sh
sudo pacman -Syu --needed sdl3 sdl3_ttf pkgconf
```

Development files are included in these packages. Keep the full system upgrade
in the command to avoid a partial upgrade.
Package references: [sdl3](https://archlinux.org/packages/extra/x86_64/sdl3/),
[sdl3_ttf](https://archlinux.org/packages/extra/x86_64/sdl3_ttf/).

## openSUSE Tumbleweed and Leap

```sh
sudo zypper refresh
zypper search -s SDL3
```

If your release's repositories provide both development packages:

```sh
sudo zypper install SDL3-devel SDL3_ttf-devel pkg-config
```

Confirm the names in your search results. Otherwise use the source install;
do not add Tumbleweed repositories to Leap to obtain SDL3.
Package search: [openSUSE](https://software.opensuse.org/search?q=SDL3).

## Alpine

```sh
sudo apk update
apk search -x sdl3-dev
apk search -x sdl3_ttf-dev
sudo apk add sdl3-dev sdl3_ttf-dev pkgconf
```

Use your installed release's community repository if needed; avoid mixing stable
and edge. If packages are unavailable, use the source install with equivalent
musl-compatible build dependencies. Run without sudo when already root.
Package search: [Alpine](https://pkgs.alpinelinux.org/packages?name=sdl3*).

## Gentoo

```sh
emerge --search libsdl3
emerge --search sdl3-ttf
sudo emerge --ask media-libs/libsdl3 media-libs/sdl3-ttf dev-util/pkgconf
```

Review the selected ebuild's USE flags for your X11/Wayland desktop and apply
your usual architecture keyword policy.
Package references: [libsdl3](https://packages.gentoo.org/packages/media-libs/libsdl3),
[sdl3-ttf](https://packages.gentoo.org/packages/media-libs/sdl3-ttf).

## Source install

Use this route for APT-based systems or when native packages are missing or too
old for your Odin bindings. Build as your normal user; only installation uses
sudo. Libraries go under `/usr/local`, separate from distro-managed `/usr` files.

### Build prerequisites

APT users should already have installed the dependencies listed above. Other
distros need Git, a C/C++ toolchain, CMake, Ninja, pkg-config, FreeType and
HarfBuzz development files, plus X11/Wayland and graphics development libraries.
Use SDL's [Linux dependency lists](https://wiki.libsdl.org/SDL3/README-linux)
for the corresponding package names. Audio/controller support is not required
by this app. Inspect CMake's summary to confirm your video backend is enabled.

### Clone, build, and install

Run the following sequence in one Bash-compatible shell. It pins SDL 3.4.18
and SDL3_ttf 3.2.2 as concrete release examples. Use a fresh working directory
if these checkout names already exist.

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

git clone --depth 1 --branch release-3.2.2 https://github.com/libsdl-org/SDL_ttf.git
cmake -S SDL_ttf -B SDL_ttf/build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_PREFIX_PATH=/usr/local \
  -DBUILD_SHARED_LIBS=ON -DSDLTTF_VENDORED=OFF \
  -DSDLTTF_SAMPLES=OFF -DSDLTTF_PLUTOSVG=OFF
cmake --build SDL_ttf/build --parallel
sudo cmake --install SDL_ttf/build
```

FreeType and HarfBuzz stay enabled. Optional SVG color-glyph support is disabled
to avoid requiring plutosvg. For X11-only builds, set `-DSDL_WAYLAND=OFF`; for
Wayland-only builds, set `-DSDL_X11=OFF`. The app itself still links libX11.

If you change versions, check the chosen SDL3_ttf release's SDL minimum first.
Sources: [SDL releases](https://github.com/libsdl-org/SDL/releases),
[SDL CMake guide](https://wiki.libsdl.org/SDL3/README-cmake),
[SDL3_ttf build options](https://github.com/libsdl-org/SDL_ttf/blob/release-3.2.2/CMakeLists.txt).

### Runtime library path

On glibc-based systems, register the library directory and refresh the loader
cache so desktop launches find the same libraries as terminal launches:

```sh
printf '%s\n' /usr/local/lib | sudo tee /etc/ld.so.conf.d/odin-clipboard-local.conf
sudo ldconfig
```

Alpine/musl has no glibc-style loader cache. Its default search path includes
`/usr/local/lib`; if a custom `/etc/ld-musl-<architecture>.path` exists, ensure
that directory is included while preserving its other entries. See the
[musl loader-path documentation](https://wiki.musl-libc.org/faq.html).

For development metadata, set this in a terminal if pkg-config cannot find the
new installation:

```sh
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
```

If Odin's linker does not search the prefix, use
`make build ODIN_FLAGS='-o:speed -extra-linker-flags:-L/usr/local/lib'`.
The runtime loader setup and the link-time search path serve different purposes.
Source-installed libraries need manual rebuilds for updates. Keep the build
directories and their `install_manifest.txt` files for maintenance.

## NixOS

NixOS uses `/nix/store` rather than conventional global library directories.
Adding SDL packages to `environment.systemPackages` alone does not configure
Odin's system-library imports or an externally built app's runtime paths.
Use a development shell or a proper Nix derivation; skip the `/usr/local` route.

For a development build, save this as `shell.nix` in the project root:

```nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  packages = with pkgs; [ odin clang gnumake python3 pkg-config binutils
                         wl-clipboard xclip ];
  buildInputs = with pkgs; [ sdl3 sdl3-ttf sqlite xorg.libX11 gtk3 ];
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath
    (with pkgs; [ sdl3 sdl3-ttf sqlite xorg.libX11 gtk3 glib gdk-pixbuf ]);
}
```

```sh
nix-shell
make build
./bin/clipboard-manager
```

Choose a nixpkgs revision providing both SDL packages. Launch from the shell;
a packaged desktop launch needs its own runtime paths and helpers.
References: [package search](https://search.nixos.org/packages?query=sdl3),
[development shells](https://nixos.org/manual/nixpkgs/stable/#sec-pkgs-mkShell).

## Verify the installation

```sh
pkg-config --modversion sdl3 sdl3-ttf
pkg-config --libs sdl3 sdl3-ttf
```

Both versions should begin with `3.`. On glibc systems, inspect the loader cache:

```sh
ldconfig -p | grep -E 'libSDL3(_ttf)?\.so'
```

Return to [Building the app](BUILDING.md#4-build-and-launch). After building,
`ldd bin/clipboard-manager` should resolve both SDL libraries without `not found`
entries. Package availability varies by distro release; these instructions are
not a claim of installation testing on every listed distribution.
