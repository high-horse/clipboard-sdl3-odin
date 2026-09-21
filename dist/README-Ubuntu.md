# Clipboard Manager for Ubuntu 24.04 (Intel/AMD)

No Odin compiler is needed. Internet access is needed for Ubuntu to install any
missing dependencies. This package is for amd64 / x86_64, not ARM or Ubuntu 22.04.

## Install and open

Open a terminal in the folder containing the package and run:

```sh
sudo apt install ./sdl3-clipboard-manager_0.1.0_amd64.deb
clipboard-manager
```

You can also open **Clipboard Manager** from the application menu. Click a card to
copy it, scroll to browse, and use **Clear all** to delete history and saved files.
Closing the window keeps the app running in the tray when tray support is available.
Choose **Quit** from the tray to stop it.

## Ubuntu desktop compatibility

For background clipboard monitoring on Ubuntu's GNOME desktop, use **Ubuntu on
Xorg**: log out, select your user, select the gear menu, choose **Ubuntu on Xorg**,
and log back in. This application uses `xclip` on X11 and `wl-clipboard` on
Wayland. GNOME Wayland can block clipboard access while the app is in the
background; installing this package does not remove that desktop restriction.
Other Wayland desktops, including COSMIC, may support background access.

The bundled libraries were built on a system based on Ubuntu 24.04. Packaging,
linking, UI rendering and single-instance behavior were checked locally; a clean
Ubuntu GNOME machine has not been used for an end-to-end test.

## Start automatically

Run this as your normal user, without sudo:

```sh
clipboard-manager-autostart enable
```

It starts quietly in the tray at your next login. To disable it:

```sh
clipboard-manager-autostart disable
```

## Keyboard shortcut

Open **Settings > Keyboard > View and Customize Shortcuts > Custom Shortcuts**.
Add a shortcut named **Clipboard Manager**, with command **clipboard-manager**.
Use **Ctrl + Alt + V**, or another available combination. Launching again opens
and raises the existing instance. On Wayland, focus follows the desktop's
activation policy.

Ubuntu normally uses **Super + V** for notifications. If you want to use it for
this app instead, reassign that existing shortcut first. Existing keyboard
shortcuts are not changed by the package.

## Remove

Disable automatic startup first, then uninstall:

```sh
clipboard-manager-autostart disable
sudo apt remove sdl3-clipboard-manager
```

History is stored in `~/.local/share/sdl3-clipboard-manager` (or under
`$XDG_DATA_HOME`). Uninstalling preserves that user data. Use **Clear all** before
uninstalling if you want to erase the saved history.

## References

- Ubuntu shortcut setup: https://help.ubuntu.com/stable/ubuntu-help/keyboard-shortcuts-set.html.en
- Wayland clipboard helper: https://github.com/bugaevc/wl-clipboard
