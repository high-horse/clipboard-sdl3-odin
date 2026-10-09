#!/usr/bin/env python3
"""Stage and package the system-library build; invoked by the root Makefile."""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / 'bin'
OUTPUT = BIN / 'packages'
NAME = 'sdl3-clipboard-manager'
FAMILIES = ('Noto_Sans', 'Noto_Sans_Arabic', 'Noto_Sans_Devanagari',
            'Noto_Sans_TC', 'Noto_Emoji')


def run(command, **kwargs):
    return subprocess.check_output(command, text=True, **kwargs).strip()


def require(*commands):
    for command in commands:
        if not shutil.which(command):
            raise RuntimeError(f'Missing {command}; see packaging/README.md for build tools.')


def write(path, text, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    path.chmod(mode)


def resources(destination):
    for family in FAMILIES:
        source = ROOT / 'noto_sans_collection' / family
        if not (source / 'OFL.txt').is_file():
            raise RuntimeError(f'Missing font license: {source / "OFL.txt"}')
    shutil.copytree(ROOT / 'noto_sans_collection', destination, dirs_exist_ok=True)


def stage(destination, prefix):
    if not prefix.startswith('/') or '..' in Path(prefix).parts:
        raise RuntimeError('PREFIX must be an absolute path without .. components.')
    base = destination / prefix.lstrip('/')
    app = base / 'lib' / NAME
    app.mkdir(parents=True, exist_ok=True)
    shutil.copy2(BIN / 'clipboard-manager', app / 'clipboard-manager')
    (app / 'clipboard-manager').chmod(0o755)
    resources(app / 'noto_sans_collection')
    bindir = base / 'bin'
    bindir.mkdir(parents=True, exist_ok=True)
    launcher = bindir / 'clipboard-manager'
    if launcher.exists() or launcher.is_symlink():
        launcher.unlink()
    launcher.symlink_to(f'../lib/{NAME}/clipboard-manager')
    helper = (ROOT / 'packaging/clipboard-manager-autostart').read_text()
    helper = helper.replace('/usr/bin/', f'{prefix.rstrip("/")}/bin/')
    # Match the file used by the app's Start at Login toggle.
    helper = helper.replace('com.example.odinsdl3clipboardmanager.desktop',
                            'sdl3-odin-clipboard-manager.desktop')
    write(bindir / 'clipboard-manager-autostart', helper, 0o755)
    desktop = (ROOT / 'packaging/com.example.odinsdl3clipboardmanager.desktop').read_text()
    desktop = desktop.replace('/usr/bin/', f'{prefix.rstrip("/")}/bin/')
    write(base / 'share/applications/com.example.odinsdl3clipboardmanager.desktop', desktop)
    docs = base / 'share/doc' / NAME
    docs.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / 'packaging/README.md', docs / 'PACKAGING.md')
    shutil.copy2(ROOT / 'docs/INSTALL-SDL3.md', docs / 'INSTALL-SDL3.md')
    write(docs / 'copyright',
          'Application: Clipboard Manager project; no project-wide license specified.\n'
          'Bundled Noto fonts: SIL Open Font License 1.1; see each font family\n'
          f'under {prefix}/lib/{NAME}/noto_sans_collection for OFL.txt.\n'
          'SDL3, SDL3_ttf, SQLite, X11, and GTK are system dependencies, not bundled.\n')
    return app / 'clipboard-manager'


def verify_binary(binary):
    require('readelf', 'ldd')
    dynamic = run(['readelf', '-d', str(binary)])
    for line in dynamic.splitlines():
        if 'RPATH' in line or 'RUNPATH' in line:
            paths = re.search(r'\[(.*?)\]', line).group(1).split(':')
            if any(not path.startswith('$ORIGIN') for path in paths):
                raise RuntimeError(f'Nonportable runtime path in binary: {line.strip()}')
    linked = run(['ldd', str(binary)])
    if 'not found' in linked:
        raise RuntimeError(f'Unresolved runtime libraries:\n{linked}')


def checksum(artifact):
    digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
    write(artifact.with_name(artifact.name + '.sha256'), f'{digest}  {artifact.name}\n')
    print(f'Created {artifact.relative_to(ROOT)}')


def deb(work, payload, binary, version, release, maintainer):
    require('dpkg-deb', 'dpkg-architecture', 'dpkg-shlibdeps')
    arch = run(['dpkg-architecture', '-qDEB_HOST_ARCH'])
    write(work / 'debian/control', f'Source: {NAME}\nMaintainer: {maintainer}\n\n'
          f'Package: {NAME}\nArchitecture: any\nDescription: Clipboard history manager\n')
    # Resolve SONAMEs and versioned symbols using this distro's package database.
    deps = run(['dpkg-shlibdeps', '-O', '-e' + str(binary)], cwd=work)
    deps = next(line.removeprefix('shlibs:Depends=') for line in deps.splitlines()
                if line.startswith('shlibs:Depends='))
    deps += ', libgtk-3-0t64 | libgtk-3-0, xclip, wl-clipboard'
    size = sum(p.stat().st_size for p in payload.rglob('*') if p.is_file())
    write(payload / 'DEBIAN/control',
          f'Package: {NAME}\nVersion: {version}-{release}\nSection: utils\n'
          f'Priority: optional\nArchitecture: {arch}\nMaintainer: {maintainer}\n'
          f'Installed-Size: {(size + 1023) // 1024}\nDepends: {deps}\n'
          'Description: Clipboard history manager with search and tray support\n'
          ' Browse, copy, pin, search, and delete text and image clipboard history.\n')
    artifact = OUTPUT / f'{NAME}_{version}-{release}_{arch}.deb'
    subprocess.run(['dpkg-deb', '--root-owner-group', '--build', str(payload),
                    str(artifact)], check=True)
    return [artifact]


def rpm(work, payload, version, release):
    require('rpmbuild')
    distro = os.environ.get('RPM_DISTRO', 'fedora')
    if distro not in ('fedora', 'opensuse'):
        raise RuntimeError('RPM_DISTRO must be fedora or opensuse.')
    gtk = 'gtk3' if distro == 'fedora' else 'libgtk-3-0'
    for name in ('BUILD', 'BUILDROOT', 'RPMS', 'SOURCES', 'SPECS', 'SRPMS'):
        (work / name).mkdir(exist_ok=True)
    with tarfile.open(work / 'SOURCES/payload.tar.gz', 'w:gz') as archive:
        archive.add(payload / 'usr', arcname='usr')
    spec = work / 'SPECS' / f'{NAME}.spec'
    write(spec, f'''Name: {NAME}
Version: {version}
Release: {release}%{{?dist}}
Summary: Clipboard history manager with search and tray support
License: LicenseRef-Unknown
Source0: payload.tar.gz
Requires: {gtk}, xclip, wl-clipboard
# Shared ELF dependencies are automatically generated by rpmbuild.
%global debug_package %{{nil}}

%description
Browse, copy, pin, search, and delete text and image clipboard history.

%prep

%build

%install
mkdir -p %{{buildroot}}
tar -xzf %{{SOURCE0}} -C %{{buildroot}}

%files
%defattr(-,root,root,-)
/usr/bin/clipboard-manager
/usr/bin/clipboard-manager-autostart
/usr/lib/{NAME}
/usr/share/applications/com.example.odinsdl3clipboardmanager.desktop
%doc /usr/share/doc/{NAME}
''')
    subprocess.run(['rpmbuild', '-bb', '--define', f'_topdir {work}', str(spec)], check=True)
    artifacts = []
    for source in (work / 'RPMS').rglob('*.rpm'):
        target = OUTPUT / source.name
        shutil.copy2(source, target)
        artifacts.append(target)
    return artifacts


def arch(work, payload, version, release):
    require('makepkg')
    if os.geteuid() == 0:
        raise RuntimeError('makepkg must run as a normal user, not root.')
    machine = platform.machine()
    # Pass the staging path via an environment variable, never shell interpolation.
    write(work / 'PKGBUILD', f'''pkgname={NAME}
pkgver={version}
pkgrel={release}
pkgdesc='Clipboard history manager with search and tray support'
arch=('{machine}')
license=('custom')
depends=('sdl3' 'sdl3_ttf' 'sqlite' 'libx11' 'gtk3' 'xclip' 'wl-clipboard')
options=('!strip' '!debug')
package() {{
    cp -a --no-preserve=ownership "$CLIPBOARD_PACKAGE_PAYLOAD/usr" "$pkgdir/"
    install -Dm644 "$CLIPBOARD_PACKAGE_PAYLOAD/usr/share/doc/{NAME}/copyright" \
        "$pkgdir/usr/share/licenses/$pkgname/copyright"
}}
''')
    env = dict(os.environ, CLIPBOARD_PACKAGE_PAYLOAD=str(payload),
               PKGDEST=str(OUTPUT), PKGEXT='.pkg.tar.zst')
    subprocess.run(['makepkg', '--force', '--nodeps', '--noconfirm'], cwd=work,
                   env=env, check=True)
    return [Path(path) for path in run(['makepkg', '--packagelist'], cwd=work,
                                     env=env).splitlines()]


def tarball(payload, version, release):
    artifact = OUTPUT / f'{NAME}-{version}-{release}-linux-{platform.machine()}.tar.gz'
    with tarfile.open(artifact, 'w:gz') as archive:
        archive.add(payload / 'usr', arcname='usr')
    return [artifact]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('format', choices=('resources', 'stage', 'install', 'auto',
                                          'deb', 'rpm', 'arch', 'tarball', 'clean'))
    parser.add_argument('--destdir', default='')
    parser.add_argument('--prefix', default='/usr/local')
    args = parser.parse_args()
    if args.format == 'clean':
        # Never remove an arbitrary caller-supplied directory or historical dist/.
        for child in BIN.iterdir():
            if child.name == '.gitkeep':
                continue
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
        return
    if args.format == 'resources':
        resources(BIN / 'noto_sans_collection')
        return
    if args.format in ('stage', 'install'):
        destination = Path(args.destdir).resolve() if args.destdir else Path('/')
        if args.format == 'stage' and not args.destdir:
            raise RuntimeError('stage requires --destdir.')
        stage(destination, args.prefix)
        print(f'Installed files under {destination / args.prefix.lstrip("/")}')
        return
    fmt = args.format
    if fmt == 'auto':
        ids = set()
        for line in Path('/etc/os-release').read_text().splitlines():
            if line.startswith(('ID=', 'ID_LIKE=')):
                ids.update(line.split('=', 1)[1].strip('"\'').split())
        if ids & {'arch', 'manjaro', 'cachyos'}:
            fmt = 'arch'
        elif ids & {'debian', 'ubuntu'}:
            fmt = 'deb'
        elif ids & {'suse', 'opensuse', 'opensuse-leap', 'opensuse-tumbleweed'}:
            fmt = 'rpm'
            os.environ['RPM_DISTRO'] = 'opensuse'
        elif ids & {'fedora', 'rhel', 'centos'}:
            fmt = 'rpm'
        else:
            fmt = 'tarball'
        print(f'Packaging format: {fmt}', flush=True)
    version = os.environ.get('VERSION', '0.1.0')
    release = os.environ.get('RELEASE', '1')
    maintainer = os.environ.get('MAINTAINER', 'Clipboard Manager project <maintainer@example.invalid>')
    if not re.fullmatch(r'[0-9]+(?:\.[0-9]+)*', version):
        raise RuntimeError('VERSION must be numeric dot-separated components, e.g. 0.2.0.')
    if not re.fullmatch(r'[1-9][0-9]*', release):
        raise RuntimeError('RELEASE must be a positive integer.')
    if '\n' in maintainer or '\r' in maintainer:
        raise RuntimeError('MAINTAINER must be a single line.')
    work = BIN / 'build' / fmt
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    payload = work / 'payload'
    binary = stage(payload, '/usr')
    verify_binary(binary)
    if fmt == 'deb':
        artifacts = deb(work, payload, binary, version, release, maintainer)
    elif fmt == 'rpm':
        artifacts = rpm(work, payload, version, release)
    elif fmt == 'arch':
        artifacts = arch(work, payload, version, release)
    else:
        artifacts = tarball(payload, version, release)
    if not artifacts:
        raise RuntimeError('Packaging tool produced no artifacts.')
    for artifact in artifacts:
        checksum(artifact)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError, StopIteration) as error:
        sys.exit(f'Packaging failed: {error}')
