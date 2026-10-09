# Packaging the app

[README](../README.md) · [Build prerequisites](../docs/BUILDING.md) · [Troubleshooting](../docs/TROUBLESHOOTING.md)

The root Makefile builds the app, stages its executable and fonts, then calls a
native packaging tool. Outputs go into `bin/packages/`, each with a `.sha256`
checksum file. Packaging does not install the app or enable autostart.

## Choose a format

| Command | Intended systems | Extra packaging tools |
| --- | --- | --- |
| `make deb` | Debian/Ubuntu family with packaged native libraries | `dpkg-deb`, `dpkg-architecture`, `dpkg-shlibdeps` |
| `make rpm` | Fedora and Enterprise Linux | `rpmbuild` |
| `make rpm RPM_DISTRO=opensuse` | openSUSE | `rpmbuild` |
| `make arch` | Arch, CachyOS, EndeavourOS, Manjaro | `makepkg`, fakeroot, libarchive, zstd |
| `make tarball` | Systems using manually installed libraries or other package managers | No additional packaging tool |
| `make package` | Automatically chooses by host distro; tarball on other hosts | Tools for the selected format |

The long aliases `package-deb`, `package-rpm`, `package-arch`, and
`package-tarball` are also supported.

**Build on the distro release and CPU architecture the package is intended for.**
Choosing RPM on an Arch host does not create a Fedora-compatible binary. Use a
matching VM/container with the app's development dependencies for each target.
Cross compilation and native APK, Gentoo, or Nix packages are not implemented.

### APT source installs and DEB packages

The [APT setup](../docs/INSTALL-SDL3.md#debian-ubuntu-mint-pop_os-raspberry-pi-os)
builds SDL under `/usr/local`. Those manually installed libraries have no Debian
package metadata, so `dpkg-shlibdeps` may be unable to generate a valid native DEB.
For that setup, use `make tarball`. To use `make deb`, first provide SDL libraries
as proper packages with dependency metadata on the target build system.
`make package` selects DEB on Debian-family hosts; use the explicit tarball target
when SDL was installed manually.

Current Makefile packages use system SDL3 and SDL3_ttf; neither library is bundled.
Recipients need compatible runtime libraries too. The old bundled-SDL Ubuntu
recipe is separate and historical; see [legacy notes](README-Ubuntu.md).

## Install packaging tools

Complete [the app build setup](../docs/BUILDING.md) first, then use the applicable
command below. Python 3.9+, `readelf`, and `ldd` are used by the packaging helper.

| Host | Command |
| --- | --- |
| Debian/Ubuntu | `sudo apt install dpkg-dev binutils` |
| Fedora/Enterprise Linux | `sudo dnf install rpm-build binutils` |
| openSUSE | `sudo zypper install rpm-build binutils` |
| Arch family | `sudo pacman -S --needed base-devel libarchive zstd binutils` |

Build packages as your normal user. Arch's makepkg refuses to run as root.

## Build, inspect, and verify

```sh
make stage
make tarball
```

Replace `make tarball` with your chosen target. `make stage` previews the `/usr`
installation tree in `bin/stage/`. Package-specific payloads and generated
recipes remain in `bin/build/<format>/` for review.

The payload contains:

| Path | Contents |
| --- | --- |
| `/usr/bin/clipboard-manager` | Symlink to the actual executable |
| `/usr/bin/clipboard-manager-autostart` | Per-user startup helper |
| `/usr/lib/sdl3-clipboard-manager/` | Executable, Noto fonts, and OFL notices |
| `/usr/share/applications/` | Desktop launcher |
| `/usr/share/doc/sdl3-clipboard-manager/` | Packaging and SDL setup notes |

DEB uses `dpkg-shlibdeps` for versioned library requirements. RPM scans ELF
library requirements. Arch declares dependency packages in the generated
PKGBUILD. GTK3 and the clipboard helpers are included in dependency declarations
because they are loaded or launched at runtime.

Before sharing, verify the artifact checksum from `bin/packages/`:

```sh
cd bin/packages
sha256sum -c sdl3-clipboard-manager-0.1.0-1-linux-x86_64.tar.gz.sha256
```

Substitute the checksum filename produced by your target. Test installation and
launch on the intended distro; creating an archive alone does not establish
runtime compatibility.

## Set release metadata

```sh
make arch VERSION=0.2.0 RELEASE=1
make deb VERSION=0.2.0 RELEASE=1 'MAINTAINER=Your Name <you@example.com>'
make rpm VERSION=0.2.0 RPM_DISTRO=opensuse
```

| Variable | Default / meaning |
| --- | --- |
| `VERSION` | `0.1.0`; numeric dot-separated components |
| `RELEASE` | `1`; positive integer packaging revision |
| `MAINTAINER` | Placeholder name/email for DEB metadata; replace for distribution |
| `RPM_DISTRO` | `fedora` or `opensuse`; selects runtime GTK package naming |
| `ODIN` | `odin`; compiler path |
| `ODIN_FLAGS` | `-o:speed`; custom build flags |

The architecture is detected from the host/native tool. Default x86_64 builds
use baseline x86-64 CPU features. No application-wide license is declared in the
repository, so metadata records an unknown/custom license rather than inventing
one. Bundled font OFL notices are included.

## Install a native package

Choose the matching command and use your artifact's actual filename:

```sh
# Debian/Ubuntu
sudo apt install ./bin/packages/sdl3-clipboard-manager_0.1.0-1_amd64.deb
```

```sh
# Fedora / Enterprise Linux
sudo dnf install ./bin/packages/sdl3-clipboard-manager-0.1.0-1*.rpm
```

```sh
# openSUSE
sudo zypper install ./bin/packages/sdl3-clipboard-manager-0.1.0-1*.rpm
```

```sh
# Arch family
sudo pacman -U ./bin/packages/sdl3-clipboard-manager-0.1.0-1-x86_64.pkg.tar.zst
```

Then launch `clipboard-manager` or select it in the application menu.
Uninstall through the same package manager. Disable autostart first if enabled;
user clipboard history is preserved. See [Using the app](../docs/USAGE.md).

## Run a tarball or stage a manual install

Extract a tarball into an empty directory and run `./usr/bin/clipboard-manager`
inside it. Its fonts are included; compatible system libraries and desktop
clipboard helpers are still required. Do not copy only the executable.

For a manual system installation, follow the staged-copy instructions in
[Building](../docs/BUILDING.md#5-install-or-package). `make install` supports
`PREFIX` (default `/usr/local`) and `DESTDIR`; without `DESTDIR` it writes directly
to the host prefix.

`make clean` removes generated `bin/` contents, not the historical `dist/` bundle
or user history.

Format references: [Debian control fields](https://www.debian.org/doc/debian-policy/ch-controlfields.html),
[RPM specs](https://rpm.org/docs/4.20.x/manual/spec.html),
[Arch PKGBUILD](https://man.archlinux.org/man/PKGBUILD.5.en).
