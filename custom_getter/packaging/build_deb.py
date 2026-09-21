#!/usr/bin/env python3
"""Build a self-contained SDL bundle in an Ubuntu 24.04 amd64 Debian package."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--odin', default=shutil.which('odin'))
parser.add_argument('--sdl-prefix', type=Path, required=True, help='Prefix containing lib/libSDL3.so and lib/libSDL3_ttf.so')
parser.add_argument('--sdl-license', type=Path, required=True)
parser.add_argument('--ttf-license', type=Path, required=True)
args = parser.parse_args()
if not args.odin:
    parser.error('--odin is required when Odin is not on PATH')
if platform.machine() != 'x86_64':
    parser.error('This package recipe currently targets x86_64 only')
prefix = args.sdl_prefix.resolve()
for source in (prefix / 'lib/libSDL3.so.0', prefix / 'lib/libSDL3_ttf.so.0', args.sdl_license, args.ttf_license):
    if not source.is_file():
        parser.error(f'Missing build input: {source}')
output = root / 'dist'
output.mkdir(exist_ok=True)
package = output / 'sdl3-clipboard-manager_0.1.0_amd64.deb'
with tempfile.TemporaryDirectory(prefix='clipboard-deb-') as temporary:
    stage = Path(temporary) / 'package'
    application = stage / 'usr/lib/sdl3-clipboard-manager'
    libraries = application / 'lib'
    binaries = stage / 'usr/bin'
    desktop = stage / 'usr/share/applications'
    docs = stage / 'usr/share/doc/sdl3-clipboard-manager'
    control = stage / 'DEBIAN'
    for directory in (libraries, binaries, desktop, docs, control):
        directory.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        args.odin, 'build', '.', f'-out:{application / "clipboard-manager"}',
        '-o:speed', '-microarch:x86-64',
        '-define:SQLITE3_SYSTEM_LIB=true', '-define:SQLITE3_DYNAMIC_LIB=true',
        f'-extra-linker-flags:-L{prefix / "lib"}',
    ], cwd=root, check=True)
    for name in ('libSDL3.so.0', 'libSDL3_ttf.so.0'):
        shutil.copy2(prefix / 'lib' / name, libraries / name, follow_symlinks=True)
    for name in ('clipboard-manager', 'clipboard-manager-autostart'):
        shutil.copy2(root / 'packaging' / name, binaries / name)
        (binaries / name).chmod(0o755)
    shutil.copy2(root / 'packaging/com.example.odinsdl3clipboardmanager.desktop', desktop)
    shutil.copy2(root / 'packaging/README-Ubuntu.md', docs)
    shutil.copy2(args.sdl_license, docs / 'SDL3-LICENSE.txt')
    shutil.copy2(args.ttf_license, docs / 'SDL3_ttf-LICENSE.txt')
    (docs / 'copyright').write_text(
        'Clipboard Manager: local project build.\n'
        'Bundled SDL3 and SDL3_ttf: Sam Lantinga and contributors, zlib license.\n'
        'See SDL3-LICENSE.txt and SDL3_ttf-LICENSE.txt.\n'
        'Other runtime libraries are provided by Ubuntu, not bundled.\n'
    )
    size = sum(p.stat().st_size for p in stage.rglob('*') if p.is_file()) // 1024
    (control / 'control').write_text(f'''Package: sdl3-clipboard-manager
Version: 0.1.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: Clipboard Manager project <maintainer@example.invalid>
Installed-Size: {size}
Depends: libc6 (>= 2.38), libsqlite3-0, libx11-6, libharfbuzz0b, libfreetype6, libgtk-3-0t64, libayatana-appindicator3-1, fonts-liberation, xclip, wl-clipboard, libwayland-client0, libwayland-cursor0, libwayland-egl1, libxkbcommon0, libxext6, libxcursor1, libxi6, libxfixes3, libxrandr2, libxss1, libegl1, libgl1
Description: Clipboard history manager with tray support
 Browse, copy, and clear clipboard history in a resizable SDL3 window.
 Includes SDL3 and SDL3_ttf runtime libraries. Intended for Ubuntu 24.04
 amd64; Ubuntu GNOME users should use an Xorg session for background
 clipboard monitoring. Automatic startup is available as a per-user option.
''')
    # No machine-specific runtime path may escape into the distributable.
    dynamic = subprocess.check_output(['readelf', '-d', str(application / 'clipboard-manager')], text=True)
    for line in dynamic.splitlines():
        if 'RPATH' in line or 'RUNPATH' in line:
            paths = re.search(r'\[(.*?)\]', line).group(1).split(':')
            if any(path not in ('$ORIGIN', '$ORIGIN/lib') for path in paths):
                raise RuntimeError(f'Unexpected runtime search path: {line}')
    env = dict(os.environ, LD_LIBRARY_PATH=str(libraries))
    linked = subprocess.check_output(['ldd', str(application / 'clipboard-manager')], env=env, text=True)
    if 'not found' in linked:
        raise RuntimeError(linked)
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(stage), str(package)], check=True)
shutil.copy2(root / 'packaging/README-Ubuntu.md', output)
digest = hashlib.sha256(package.read_bytes()).hexdigest()
(output / 'SHA256SUMS').write_text(f'{digest}  {package.name}\n')
print(f'Ready to share: {package} ({package.stat().st_size / 1024 / 1024:.1f} MiB)')
