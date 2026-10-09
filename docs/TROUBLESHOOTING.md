# Troubleshooting

[README](../README.md) · [Building](BUILDING.md) · [SDL3 setup](INSTALL-SDL3.md)

## Build cannot find SDL3 or SDL3_ttf

Both native libraries are required, even though Odin includes their bindings.
Check development metadata:

```sh
pkg-config --modversion sdl3 sdl3-ttf
pkg-config --libs sdl3 sdl3-ttf
```

On APT-based systems, follow the clone/build/install steps in the
[SDL3 guide](INSTALL-SDL3.md#source-install). For a source install under
`/usr/local`, set the pkg-config path if needed:

```sh
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
make build ODIN_FLAGS='-o:speed -extra-linker-flags:-L/usr/local/lib'
```

If linking reports an undefined SDL symbol, the installed SDL may be older than
your Odin bindings require. Install compatible SDL3 and SDL3_ttf versions, then
rebuild. SDL2 cannot satisfy SDL3 imports.

## The app reports a missing shared library

```sh
ldd bin/clipboard-manager
```

Resolve every `not found` entry. On glibc systems with an SDL source install,
register `/usr/local/lib` and refresh the loader cache as described in
[SDL3 setup](INSTALL-SDL3.md#runtime-library-path). This is needed for desktop
launches as well as terminal launches. Alpine/musl and NixOS use different
library-path mechanisms; see their sections in that guide.

## Failed to load primary Noto Sans font

Rebuild the app with `make build`, which copies the bundled fonts into `bin/`.
The executable needs `noto_sans_collection/` beside it. Keep the executable and
that directory together when moving a build.

For an installed package, reinstall the package if its font directory under
`/usr/lib/sdl3-clipboard-manager/` is missing.

## No clipboard history or copying fails

Launch from your graphical desktop as your normal user, with its session
environment intact:

```sh
printf 'Runtime: %s\nWayland: %s\nX11: %s\n' \
  "$XDG_RUNTIME_DIR" "$WAYLAND_DISPLAY" "$DISPLAY"
command -v wl-copy wl-paste xclip
```

The app selects Wayland when `WAYLAND_DISPLAY` is present, otherwise X11 when
`DISPLAY` is present. Install `wl-clipboard` for Wayland or `xclip` for X11.
Avoid launching through sudo, a detached SSH session, or a system service that
lacks your desktop session environment.

Wayland clipboard access depends on the compositor. A window that opens
successfully does not guarantee background clipboard monitoring is supported.
If your desktop restricts it, test in an X11 login session where available.

## Tray icon or advanced popup controls are missing

The native tray requires GTK3, GLib/GIO, GdkPixbuf, a session D-Bus connection,
and a desktop StatusNotifierItem host. Install GTK3 and enable your desktop's
tray/status-area support. Some GNOME configurations need an appropriate shell
extension. Restart the app after changing tray support.

The app can fall back to SDL's tray backend. That backend may need AppIndicator
runtime libraries and has simpler menu behavior. A missing search field,
thumbnail, or separate trash button can indicate this fallback is active.
If neither tray backend is available, use the main window; closing it exits.

## Resource readings are missing

Enlarge the window to at least 640 × 500 to show the sidebar. GPU usage requires
`gpu_busy_percent` support from the DRM driver. An unavailable GPU reading does
not prevent clipboard features from working.

## Packaging fails

Check `make help` and the [packaging guide](../packaging/README.md). Install the
native packaging tool for the requested format and build on the intended target
distro/release. Arch's makepkg must run as a normal user.

DEB dependency scanning requires package metadata for linked system libraries.
Libraries manually installed in `/usr/local` may not have that metadata. Use the
current tarball workflow for a source-installed SDL setup, or package SDL itself
before building a native DEB. The older bundled Ubuntu recipe is documented
separately in [the legacy notes](../packaging/README-Ubuntu.md).

## Collect useful diagnostics

Include your distro/release, desktop, X11/Wayland session, and whether you used a
source build or a package. These commands help identify the build and linkage:

```sh
cat /etc/os-release
odin version
pkg-config --modversion sdl3 sdl3-ttf
ldd bin/clipboard-manager
```

For an installed copy, run `ldd` on its actual executable under the installation
prefix. Review terminal output before sharing it: the app logs captured text.
