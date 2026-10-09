# Using the app

[README](../README.md) · [Building](BUILDING.md) · [Troubleshooting](TROUBLESHOOTING.md)

## Window

Copy something in another application to add it to history. Click a history
card or its clipboard icon to copy it again. PNG and JPEG entries show image
previews. Line breaks appear as bent arrows and tabs as spaces in text previews;
copying preserves the original content.

Use the pin icon to mark a favorite. Favorites stay above ordinary history and
are excluded from automatic history trimming. Click the pin again to unpin.
The trash icon deletes one entry. **Clear all** removes the entire saved history,
including favorites. These actions do not have an undo feature.

Type in the search field to filter history. Search is case-insensitive and
matches saved text, MIME types, and item labels. Image contents are not OCR'd.
Window and tray searches are independent.

The resource sidebar appears when the window is at least 640 × 500 pixels.
CPU and RAM are system-wide readings; disk usage is for the filesystem containing
the app's data directory. GPU usage depends on a driver busy counter and may
show unavailable. These readings are not per-process usage.

## Tray

Open the tray icon to browse history without opening the main window. The native
popup has search, image previews, and a trash icon beside each item:

- Click an item to copy it and close the popup.
- Click its trash icon to delete it while keeping the popup open.
- Use Previous/Next to browse 10 items per page.
- Reopening the popup resets to page 1 and scrolls to the top; search text is retained.
- Show/Hide reflects whether the main window is visible.
- **Start at Login** toggles automatic startup; **Quit** stops the app.

These popup controls require the native GTK/StatusNotifierItem backend. The SDL
tray fallback has simpler menu entries and pagination; it does not provide the
native search field, thumbnails, or separate trash buttons.

Closing the main window keeps monitoring active while a tray backend exists.
Without a tray backend, closing it exits. `--background` starts hidden only when
a tray backend can be created.

## Keyboard controls

| Key | Action |
| --- | --- |
| Ctrl+F | Focus window search and select the query |
| Ctrl+A / Ctrl+V | Select all / paste while search is focused |
| Ctrl+U | Clear the focused search field |
| Up / Down | Select a history entry |
| Enter | Copy the selected entry; from search, select the first match if needed |
| Home / End | Select first / last entry when search is not focused |
| Space | Copy the selected entry when search is not focused |
| Delete | Delete the selected entry when search is not focused |
| P | Toggle the selected entry's pin when search is not focused |
| Escape | Clear a nonempty focused search; otherwise close/hide the window |

In the native tray search field, Enter copies the first match on the current
page. Escape dismisses the tray popup.

## Start at login and desktop shortcuts

The tray's **Start at Login** option works for source builds as well as installed
packages. It records the executable's current path, so moving or cleaning a
source build can break that startup entry. Prefer an installed copy for autostart.

Installed packages also provide:

```sh
clipboard-manager-autostart enable
clipboard-manager-autostart disable
```

Run these as your normal user. They manage a per-user desktop entry at
`$XDG_CONFIG_HOME/autostart/sdl3-odin-clipboard-manager.desktop`, defaulting to
`~/.config/autostart/`.

The app does not register a global hotkey. Create one in your desktop's keyboard
settings using `clipboard-manager` as the command, or the absolute path to
`bin/clipboard-manager` for a source build. Launching it again activates the
existing instance. Window focus follows your desktop's activation policy.

## Saved data and history limit

Data lives under `$XDG_DATA_HOME/sdl3-clipboard-manager`, or
`~/.local/share/sdl3-clipboard-manager` when `XDG_DATA_HOME` is unset.

| File | Purpose |
| --- | --- |
| `cd.slm` | SQLite history database, including favorites |
| `blobs/` | Stored clipboard payload files |
| `cfg.jsn` | History configuration |

The default limit is **5 unpinned entries**. To change it, quit the app and edit
`cfg.jsn`, then restart. For example:

```json
{
  "max_entries": 100
}
```

A value of zero or less disables automatic trimming. Favorites do not count
against this limit, but can still be deleted explicitly or by Clear all.

History is local and unencrypted. Captured text is currently printed to the
terminal too, so redirected logs may contain clipboard contents. Removing a
package preserves user data; Clear all removes saved history and its blobs.
