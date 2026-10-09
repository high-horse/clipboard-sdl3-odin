# Legacy Ubuntu bundle

This document describes the older bundled-SDL workflow, not the current Makefile
packaging targets. For new builds, start with [Packaging](README.md).

## Existing artifact

`dist/sdl3-clipboard-manager_0.1.0_amd64.deb` is a historical Ubuntu 24.04 amd64
build. It predates current source changes and is not a release of the current
app. It bundles SDL3 and SDL3_ttf; the current Makefile packages use system
libraries instead. The old installer was built for glibc 2.38 or newer and is
not intended for Ubuntu 22.04 or ARM systems.

The bundled artifact's presence does not establish compatibility with other
Ubuntu releases or a clean GNOME desktop. Prefer a fresh build for your target.

## Old builder

`build_deb.py` takes an Odin compiler, an SDL installation prefix, and the SDL
license files. Its dependencies and payload reflect the older app layout; it
is retained for reference and needs review before use with current source.
It is not invoked by `make deb`.

The original invocation was:

```sh
python3 packaging/build_deb.py \
  --odin /path/to/odin \
  --sdl-prefix /path/to/sdl-prefix \
  --sdl-license /path/to/SDL/LICENSE.txt \
  --ttf-license /path/to/SDL_ttf/LICENSE.txt
```

It writes to `dist/`, unlike current builds under `bin/`. Do not use the old
bundle's instructions to infer requirements or features of a current package.
