# Building distro packages

Run GNU Make from the project root. Python 3, Odin, Clang/linker, `readelf`, and
`ldd` are required. Install SDL3, SDL3_ttf, SQLite, and X11 development packages
first; see [SDL3 installation](../docs/INSTALL-SDL3.md) and the main README.

```sh
make help
make build
./bin/clipboard-manager
make stage
make package
```

`make build` puts the executable and its Noto fonts in `bin/`. `make stage`
shows the complete installation tree in `bin/stage/`. `make package` selects DEB
on Debian/Ubuntu, RPM on Fedora/Enterprise Linux/openSUSE, Arch on Arch-based
systems, and a tarball elsewhere. Artifacts and individual SHA-256 checksum
files are written to `bin/packages/`. Build tools never install the package or
enable autostart automatically.

## Package targets

| Target | Distributions | Additional tools |
| --- | --- | --- |
| `make deb` / `make package-deb` | Debian, Ubuntu, Mint, Pop!_OS, Raspberry Pi OS | `dpkg-deb`, `dpkg-architecture`, `dpkg-shlibdeps` (dpkg-dev) |
| `make rpm` / `make package-rpm` | Fedora, RHEL, Rocky, AlmaLinux, CentOS Stream | `rpmbuild` (rpm-build) |
| `make rpm RPM_DISTRO=opensuse` | openSUSE Tumbleweed/Leap | `rpmbuild` (rpm-build) |
| `make arch` / `make package-arch` | Arch, CachyOS, EndeavourOS, Manjaro | `makepkg`, `fakeroot`, `bsdtar`, `zstd` (base-devel plus libarchive/zstd) |
| `make tarball` / `make package-tarball` | Other conventional Linux systems | Python 3 standard library |

Examples of packaging-tool installation (in addition to app build dependencies):

```sh
# Debian/Ubuntu
sudo apt install make python3 binutils dpkg-dev
# Fedora / Enterprise Linux
sudo dnf install make python3 binutils rpm-build
# openSUSE
sudo zypper install make python3 binutils rpm-build
# Arch family
sudo pacman -S --needed base-devel python binutils libarchive zstd
```

Run the applicable command for your distro, not all four. Use normal user
permissions for builds; Arch's makepkg explicitly refuses root.

Build **on the distro release and architecture you intend to distribute to**.
Changing the package format does not convert the binary's libc or other ABI
requirements. For example, an Arch-built RPM is not a Fedora-compatible build.
Use a matching VM/container with all development dependencies for each target.
Neither ARM cross compilation nor native APK/Gentoo/Nix packaging is provided;
the tarball uses the build host's ABI, including musl when built on Alpine.

These packages depend on system SDL3 and SDL3_ttf; they do not bundle them.
DEB dependencies are computed by `dpkg-shlibdeps`, and RPM's native ELF scanner
generates shared-library requirements. Arch declares its runtime packages in
the generated PKGBUILD. GTK3, `xclip`, and `wl-clipboard` are also declared for
the tray and clipboard backends. If distro SDL packages are unavailable, native
dependency resolution may fail even when `/usr/local` libraries work: use a
matching library package or the tarball instead.

## Versions and options

```sh
make deb VERSION=0.2.0 RELEASE=1 'MAINTAINER=Your Name <you@example.com>'
make rpm VERSION=0.2.0 RPM_DISTRO=opensuse
make build ODIN=/path/to/odin ODIN_FLAGS='-o:speed -extra-linker-flags:-L/usr/local/lib'
```

`VERSION` accepts numeric dot-separated versions and `RELEASE` a positive
integer. The default version is `0.1.0-1`. The architecture comes from the build
host/native packaging tool. x86_64 builds use the baseline `x86-64`
microarchitecture to avoid requiring the build machine's CPU extensions.
Native package recipes and staging files remain under `bin/build/<format>/`
for inspection. The repository has no project-wide application license;
metadata records this as unknown, and bundled font OFL notices are included.

## Install and remove

Use the package manager on the matching target system:

```sh
sudo apt install ./bin/packages/sdl3-clipboard-manager_0.1.0-1_amd64.deb
sudo dnf install ./bin/packages/sdl3-clipboard-manager-0.1.0-1*.rpm
sudo zypper install ./bin/packages/sdl3-clipboard-manager-0.1.0-1*.rpm
sudo pacman -U ./bin/packages/sdl3-clipboard-manager-0.1.0-1-x86_64.pkg.tar.zst
```

Choose the command for your distro and substitute your actual artifact name.
Launch `clipboard-manager` or use the application menu. The binary and fonts
are installed under `/usr/lib/sdl3-clipboard-manager/`, with a launcher symlink
in `/usr/bin/` and a desktop entry under `/usr/share/applications/`.

The tarball contains that same `usr/` tree. To preview it without installation,
extract into an empty directory and run `./usr/bin/clipboard-manager` there.
System runtime dependencies still need to be installed. For an unpackaged
installation, GNU Make supports a prefix and staged destination:

```sh
make install PREFIX=/usr/local DESTDIR=/tmp/clipboard-install
# Inspect /tmp/clipboard-install/usr/local before copying into the host.
```

`make install` without `DESTDIR` writes to the host prefix and may require root.
It builds first, so prefer building/staging as your normal user, then copying
the staged files with the privileges required for your destination.

Automatic startup is opt-in through the tray or
`clipboard-manager-autostart enable`; use `clipboard-manager-autostart disable`
before removal. Remove native packages with your distro's package manager.
Clipboard history in the user's data directory is preserved.

```sh
make check
make test
make clean
```

`make clean` removes generated contents of `bin/`, preserving `.gitkeep` and
the historical Ubuntu bundle in `dist/`. The older `packaging/build_deb.py`
remains a separate bundled-SDL Ubuntu recipe; it is not used by these targets.

Format references: [Debian control fields](https://www.debian.org/doc/debian-policy/ch-controlfields.html),
[RPM specs](https://rpm.org/docs/4.20.x/manual/spec.html),
[Arch PKGBUILD](https://man.archlinux.org/man/PKGBUILD.5.en).
