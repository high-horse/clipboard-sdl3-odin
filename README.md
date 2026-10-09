# Odin Clipboard Manager

A Linux desktop clipboard manager built with Odin and SDL3. It keeps clipboard
history in a local SQLite database and lets you reuse items from a window or
system tray.

## What it does

- Saves text, links/file URI lists, and PNG/JPEG clipboard images.
- Shows image previews and readable markers for line breaks.
- Searches history in the window and native tray popup.
- Pins favorites above ordinary history and protects them from automatic trimming.
- Deletes individual entries or clears the entire history.
- Shows tray history in pages of 10, resetting to page 1 when reopened.
- Displays system CPU, RAM, supported GPU, and disk usage in the window sidebar.

Closing the window keeps the app running when a tray backend is available.
Choose **Quit** in the tray to exit. Without a tray backend, closing the window
exits the app.

## Build and run

Use a terminal inside your logged-in Linux desktop session. Start in the project
root, where `main.odin` and `Makefile` live.

1. Follow [Building on Linux](docs/BUILDING.md) to install Odin and native dependencies.
2. Install SDL3 and SDL3_ttf using [the SDL3 guide](docs/INSTALL-SDL3.md).
   On APT-based systems, clone and build both libraries from source.
3. Build and launch:

```sh
make build
./bin/clipboard-manager
```

Keep `bin/noto_sans_collection/` next to the executable. `make build` copies it
for you. Run the app as your normal desktop user.

If you already have a package built for your distribution release and CPU
architecture, install it with your package manager instead; Odin is only needed
to build from source.

## Documentation

| Guide | Use it for |
| --- | --- |
| [Building on Linux](docs/BUILDING.md) | Toolchain, app dependencies, build commands, installation |
| [Installing SDL3](docs/INSTALL-SDL3.md) | System-wide SDL3 and SDL3_ttf setup by distribution |
| [Using the app](docs/USAGE.md) | Search, favorites, tray, shortcuts, autostart, saved data |
| [Packaging](packaging/README.md) | DEB, RPM, Arch packages, tarballs, and release options |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Missing libraries, fonts, tray support, and clipboard access |

## Development

```sh
make check
make test
make help
```

Builds and test executables go into `bin/`. `make clean` removes generated
contents there. The `clipboard/` directory contains the X11 and Wayland helpers;
`tray_backend/` contains the GTK/StatusNotifierItem tray and SDL fallback.

## Current limits

This is a Linux application. Clipboard access depends on the desktop session;
Wayland compositors can restrict background monitoring. The native tray needs
GTK3 and a desktop StatusNotifierItem host. The SDL fallback has fewer popup
features. GPU usage appears only when the driver exposes a supported busy counter.

The app stores clipboard contents unencrypted and currently prints captured text
to its terminal output. See [saved data](docs/USAGE.md#saved-data-and-history-limit)
before choosing a history limit or sharing logs.

The project has no declared application-wide license. Bundled Noto fonts include
their SIL Open Font License notices. The old Ubuntu bundle in `dist/` predates
the current app; use the Makefile for new builds.
