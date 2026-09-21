# SDL3 Odin Clipboard Manager — Build Instructions

This document covers every dependency required to **build**, **run**, and **test** this
project, on **any major Linux distro** and on **any display server
(X11, Wayland, or X11-over-Wayland / XWayland)**.

---

## 1. Dependency map

| # | Dependency | Why it is required | Category |
|---|-----------|--------------------|----------|
| 1 | **Odin compiler** (`odin`) | Compiles the whole project (`.odin` sources) | Language toolchain |
| 2 | **C/C++ toolchain** (`gcc`/`clang`), `make`, `pkg-config`, `cmake`, `ninja`, `git` | Build the project and (on some distros) build SDL3 from source | Build tools |
| 3 | **SDL3** (`libSDL3.so`) | Graphics/window/event loop via `vendor:sdl3` | Runtime + dev library |
| 4 | **SDL3_ttf** (`libSDL3_ttf.so`) | Font rendering via `vendor:sdl3/ttf` (`ttf.OpenFont`, `ttf.RenderText_Blended`) | Runtime + dev library |
| 5 | **X11 dev libraries** (`libX11`, `libXcursor`, `libXfixes`, `libXrandr`, `libXi`) | Literal linking of `vendor:x11/xlib` in `clipboard/x11.odin` | Dev libraries |
| 6 | **xclip** | X11 clipboard backend (`clipboard/x11.odin`) — reads/writes the X selection | Runtime CLI tool |
| 7 | **wl-clipboard** (`wl-copy`, `wl-paste`) | Wayland clipboard backend (`clipboard/wayland.odin`) | Runtime CLI tool |
| 8 | **Unicode-capable TrueType fonts** (`FreeSans`/`DejaVuSans`/`NotoSans`, plus optional **NotoColorEmoji** and **NotoSansCJK** fallbacks) | Font rendering with broad **Unicode/emoji/CJK** coverage. The app auto-detects fonts from a list of standard paths; rendering falls back between fonts (see §6) | Runtime data |
| 9 | **SQLite 3** | Database storage — **statically bundled** in `sqlite3/libsqlite3.a`. No system package needed to build. | Bundled |
| 10 | *(optional)* **OLS** (`ols`) | If you use the editor language support configured by `ols.json` | Dev tool |

### Compositor / display-server notes

- The clipboard backend is auto-selected in `clipboard/create()`:
  1. `WAYLAND_DISPLAY` is set → try **Wayland** (needs `wl-copy`/`wl-paste`)
  2. else `DISPLAY` is set → try **X11** (needs `xclip`)
  3. neither → the app prints `Could not initialize clipboard.` and exits.
- This means the same build works on **pure Wayland compositors** (GNOME/Wayland,
  KDE/Wayland, sway, Hyprland, …), **pure X11** desktop sessions, and **XWayland**
  sessions (where an XWayland `DISPLAY` exists alongside `WAYLAND_DISPLAY`).

---

## 2. Install the Odin compiler

Requires `git`, `make`, and a C compiler (`gcc` or `clang`) plus libc headers
(`glibc` dev or musl). Grab the **latest nightly** (the project targets current
`dev-` nightly builds, e.g. `dev-2026-09-nightly`).

```bash
git clone --recursive https://github.com/odin-lang/Odin /opt/odin
cd /opt/odin
make                  # build the `odin` binary
sudo ln -s /opt/odin/odin /usr/local/bin/odin
odin version          # verify
```

Faster alternative: build the official nightly snapshot

```bash
cd /opt/odin
./build_Odin.sh --dev-release   # compiler flags optimized release nightly
sudo cp odin /usr/local/bin/
```

**Optional — OLS (Odin Language Server):**

```bash
git clone https://github.com/DanielGavin/ols /opt/ols
cd /opt/ols
make
sudo ln -s /opt/ols/ols /usr/local/bin/ols
```

> On some distros Odin is also packaged in the community repos (e.g. the AUR
> package `odin`). A system package is fine as long as its vendor dir ships
> `vendor/sdl3`, `vendor/sdl3/ttf`, and `vendor/x11`, which the stock Odin
> distribution does.

---

## 3. Install SDL3 and SDL3_ttf

Two paths:

### 3a. Install from your distro's package manager (preferred)

These packages are now available in most recent distros:

| Distro family | Package manager | SDL3 | SDL3_ttf | Optional dev extras |
|---|---|---|---|---|
| **Arch / Arch-based** | `pacman` | `sdl3` | `sdl3_ttf` | already pulled in |
| **Fedora / RHEL / Rocky / Alma** (F40+) | `dnf` | `SDL3-devel` | `SDL3_ttf-devel` | `libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| **Debian 13 "trixie" / sid / newer Ubuntu (26.04+)** | `apt` | `libsdl3-dev` | `libsdl3-ttf-dev` | `libx11-dev libxcursor-dev libxfixes-dev libxrandr-dev libxi-dev` |
| **openSUSE Tumbleweed** | `zypper` | `SDL3-devel` | `SDL3_ttf-devel` | `libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| **Void Linux** | `xbps` | `SDL3-devel` | `SDL3_ttf-devel` | `libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| **Gentoo** | `emerge` | `media-libs/sdl3` | `media-libs/sdl3-ttf` | `x11-libs/libX11 x11-libs/libXcursor x11-libs/libXfixes x11-libs/libXrandr x11-libs/libXi` |
| **NixOS** (`nix-shell`) | `nix` | `sdl3` | `sdl3_ttf` | `libX11 libXcursor libXfixes libXrandr libXi` |

> Older releases may not carry SDL3 yet. If your distro doesn't have the packages
> above, skip to **3b** and build from source. Prefer *dev* packages: Odin resolves
> `system:SDL3` / `system:SDL3_ttf` at link time.

### 3b. Build SDL3 + SDL3_ttf from source (universal fallback)

Works identically on every distro. Recommended `cmake` deps on Debian/Ubuntu for a
full-featured build: `libx11-dev libxext-dev libxrandr-dev libxcursor-dev
libxi-dev libxfixes-dev libxkbcommon-dev libxkbcommon-x11-dev
libwayland-dev wayland-protocols libdecor-dev libpipewire-0.3-dev
libpulse-dev libdbus-1-dev` (adjust names per distro; a minimal video-only build
works with just the X11 dev libs anyway).

```bash
# --- SDL3 ---
git clone --depth 1 --branch SDL3 https://github.com/libsdl-org/SDL.git
cd SDL
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
sudo cmake --install build
cd ..

# --- SDL3_ttf (pulls in FreeType/Harfbuzz automatically) ---
git clone https://github.com/libsdl-org/SDL_ttf.git
cd SDL_ttf
cmake -S . -B build -DSDL3TTF_INSTALL=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
sudo cmake --install build
cd ..
```

Building from source installs to `/usr/local`, which the dynamic linker may not
search by default. Fix that once:

```bash
echo '/usr/local/lib' | sudo tee /etc/ld.so.conf.d/local.conf
sudo ldconfig
```

---

## 4. Install the X11 development libraries

Required because `clipboard/x11.odin` links `vendor:x11/xlib` (which imports
`system:X11`, `system:Xcursor`, `system:Xfixes`, `system:Xrandr`, `system:Xi`).

| Distro family | Command |
|---|---|
| Debian / Ubuntu | `sudo apt install libx11-dev libxcursor-dev libxfixes-dev libxrandr-dev libxi-dev` |
| Fedora / RHEL / Rocky / Alma | `sudo dnf install libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| Arch / Arch-based | `sudo pacman -S libx11 libxcursor libxfixes libxrandr libxi` |
| openSUSE | `sudo zypper install libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| Void Linux | `sudo xbps-install libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel` |
| Gentoo | `sudo emerge -av x11-libs/libX11 x11-libs/libXcursor x11-libs/libXfixes x11-libs/libXrandr x11-libs/libXi` |
| NixOS | `libX11 libXcursor libXfixes libXrandr libXi` (add to `buildInputs`) |

---

## 5. Install the clipboard helper tools

These are plain runtime binaries, needed for both backends. Install **both** —
the app picks them automatically based on your session type.

| Tool | Provides | Distro packages |
|---|---|---|
| **xclip** | X11 clipboard read/write (`xclip -selection clipboard …`) | Debian/Ubuntu `xclip`, Fedora `xclip`, Arch `xclip`, openSUSE `xclip`, Void `xclip`, Gentoo `x11-misc/xclip` |
| **wl-clipboard** | Wayland read/write (`wl-copy`, `wl-paste`) | Debian/Ubuntu `wl-clipboard`, Fedora `wl-clipboard`, Arch `wl-clipboard`, openSUSE `wl-clipboard`, Void `wl-clipboard`, Gentoo `gui-apps/wl-clipboard` |

```bash
# Examples — pick your package manager
sudo apt install xclip wl-clipboard                 # Debian/Ubuntu
sudo dnf install xclip wl-clipboard                 # Fedora/RHEL
sudo pacman -S xclip wl-clipboard                   # Arch
sudo zypper install xclip wl-clipboard              # openSUSE
sudo xbps-install xclip wl-clipboard                # Void
sudo emerge -av x11-misc/xclip gui-apps/wl-clipboard # Gentoo
```

---

## 6. Install fonts

The app loads its primary font from a **candidate list** (`FreeSans` → `DejaVuSans` →
`Noto Sans`) and automatically attaches **fallback fonts** for broader Unicode
coverage: `NotoColorEmoji` (emoji) and `NotoSansCJK` (CJK). Install whichever are
available so text (including emoji and non-Latin scripts) renders instead of
showing boxes:

| Distro family | Command (adds coverage) |
|---|---|
| Debian / Ubuntu | `sudo apt install fonts-freefont-ttf fonts-noto-color-emoji fonts-noto-cjk` |
| Arch / Arch-based | `sudo pacman -S ttf-freefont ttf-dejavu noto-fonts-emoji noto-fonts-cjk` |
| Fedora / RHEL | `sudo dnf install freefont-ttf dejavu-sans-fonts google-noto-emoji-fonts google-noto-sans-cjk-fonts` |
| openSUSE | `sudo zypper install freefont-ttf dejavu-fonts google-noto-emoji-fonts google-noto-sans-cjk-fonts` |
| Void Linux | `sudo xbps-install freefont-ttf dejavu-fonts-ttf noto-fonts-emoji noto-fonts-cjk` |
| Gentoo | `sudo emerge -av media-fonts/freefont media-fonts/dejavu media-fonts/noto-emoji media-fonts/noto-cjk` |

> Only the first available primary font is required for the app to start. If the
> exact font file is missing, the loader walks the candidate list (Debian,
> Arch, and Fedora each lay fonts out at different paths).

---

## 7. SQLite 3 (bundled — nothing to install)

The project ships a static SQLite archive at `sqlite3/libsqlite3.a` and links it
directly (see `sqlite3/sqlite.odin`). **No system SQLite package is required.**
A distro `sqlite3`/`libsqlite3` package is only needed if you ever run the app
with `-define:SQLITE3_SYSTEM_LIB=true`.

---

## 8. Verify every dependency

Run these checks; every command should succeed:

```bash
echo "== Odin ==";            odin version
echo "== SDL3 ==";            pkg-config --modversion sdl3 2>/dev/null || ldconfig -p | grep libSDL3.so
echo "== SDL3_ttf ==";        pkg-config --modversion sdl3-ttf 2>/dev/null || ldconfig -p | grep libSDL3_ttf.so
echo "== X11 libs ==";        pkg-config --exists x11 && echo OK
echo "== xclip ==";           command -v xclip
echo "== wl-copy/wl-paste =="; command -v wl-copy && command -v wl-paste
echo "== FreeSans font ==";   ls /usr/share/fonts/truetype/freefont/FreeSans.ttf
echo "== Session ==";         echo "DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
```

Expected / accepted results:

| Check | Expected |
|---|---|
| `odin version` | prints e.g. `dev-2026-09-nightly:…` |
| SDL3 | `3.x.y` or a `libSDL3.so[.0]` line |
| SDL3_ttf | `3.x.y` or a `libSDL3_ttf.so[.0]` line |
| X11 libs | `OK` |
| xclip / wl-copy / wl-paste | absolute paths |
| FreeSans | the `.ttf` file path |
| Session | at least one of `DISPLAY` / `WAYLAND_DISPLAY` set (only relevant at run time) |

---

## 9. Build and run

```bash
cd custom_getter
odin build . -out:custom_getter      # produces ./custom_getter
```

### Run (from a graphical session)

```bash
./custom_getter
```

You must be logged into an **X11 or Wayland session** (or have `WAYLAND_DISPLAY`
or `DISPLAY` exported) — the clipboard backend cannot initialize in a pure headless
environment.

---

## 10. Test the application

1. **Startup log** — expect:
   ```
   Data directory: …/sdl3-clipboard-manager
   Database: …/cd.slm
   Database connected
   Database tables prepared.
   setting content : 'sdl.SetClipboardData() is working!'
   ```
2. **Font test** — if you see *"Failed to load any font"* you skipped step 6.
   Expected boot log lines like `using font: /usr/share/fonts/truetype/freefont/FreeSans.ttf`
   followed by any found fallbacks (emoji/CJK).
3. **Clipboard set test** — the app writes `sdl.SetClipboardData() is working!`
   into the clipboard at startup. Verify the selection independently:
   - X11: `xclip -selection clipboard -o`
   - Wayland: `wl-paste --no-newline`
4. **Clipboard watch test** — while the app runs, in another window copy some text
   (`Ctrl+C`). The app's console prints:
   ```
   Clipboard changed: mime=text/plain, size=N bytes
   Text: …
   ```
   and the text appears in the on-screen 600×400 list (newest on top).
5. **Database test** — confirm rows and blobs were written:
   ```bash
   sqlite3 "$HOME/.local/share/sdl3-clipboard-manager/cd.slm" \
     'SELECT content_path, mime, hash FROM clipboard_contents ORDER BY id DESC LIMIT 5;'
   ```
   Each entry has a matching blob file under `~/.local/share/sdl3-clipboard-manager/blobs/`.
6. **Quit** — press `ESC` or close the window. The worker thread exits cleanly
   (`worker returned`, `exiting ...`).

---

## 11. Compositor & distro compatibility cheat-sheet

| Session type | Backend used | Tools required | Notes |
|---|---|---|---|
| X11 desktop (GNOME/X11, KDE/X11, XFCE, i3, openbox…) | **X11** | `xclip` | Default when `DISPLAY` set and no `WAYLAND_DISPLAY` |
| Pure Wayland (GNOME/Wayland, KDE/Wayland, sway, Hyprland, river…) | **Wayland** | `wl-copy`, `wl-paste` | Selected first if `WAYLAND_DISPLAY` is set |
| XWayland apps on a Wayland session | **X11** (via xclip) | `xclip` | `WAYLAND_DISPLAY` is also set, so Wayland takes priority |
| Headless / no display | — | — | `clipboard.create()` fails; app exits with *"Could not initialize clipboard."* |

**TL;DR per distro:**

```bash
# Debian/Ubuntu (trixie+, or build SDL3 for older)
sudo apt install odin libsdl3-dev libsdl3-ttf-dev \
     libx11-dev libxcursor-dev libxfixes-dev libxrandr-dev libxi-dev \
     xclip wl-clipboard fonts-freefont-ttf

# Fedora (F40+)
sudo dnf install SDL3-devel SDL3_ttf-devel \
     libX11-devel libXcursor-devel libXfixes-devel libXrandr-devel libXi-devel \
     xclip wl-clipboard freefont-ttf

# Arch
sudo pacman -S sdl3 sdl3_ttf libx11 libxcursor libxfixes libxrandr libxi \
     xclip wl-clipboard ttf-freefont
```