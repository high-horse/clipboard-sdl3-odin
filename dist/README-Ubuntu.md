# Historical Ubuntu package

The file `sdl3-clipboard-manager_0.1.0_amd64.deb` in this directory is an older
Ubuntu 24.04 amd64 build. It includes bundled SDL libraries and predates the
current application source. It is not the package produced by today's Makefile.

For a current build, follow the repository README and `packaging/README.md`.
New executables go into `bin/`; new packages go into `bin/packages/`.
The legacy builder is described in `packaging/README-Ubuntu.md`.

This artifact targets Intel/AMD 64-bit systems with glibc 2.38 or newer, not ARM
or Ubuntu 22.04. Check its original checksum before using it:

```sh
sha256sum -c SHA256SUMS
```

Run the checksum command from this directory. Existing clipboard data is stored
per user under `~/.local/share/sdl3-clipboard-manager` unless `XDG_DATA_HOME`
overrides that location. Uninstalling a package does not erase that data.
