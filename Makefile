SHELL := /bin/sh
.DEFAULT_GOAL := build

ODIN ?= odin
PYTHON ?= python3
VERSION ?= 0.1.0
RELEASE ?= 1
PREFIX ?= /usr/local
DESTDIR ?=
ODIN_FLAGS ?= -o:speed
# Avoid requiring the build machine's CPU extensions in distributed binaries.
ifeq ($(shell uname -m),x86_64)
ODIN_FLAGS += -microarch:x86-64
endif
MAINTAINER ?= Clipboard Manager project <maintainer@example.invalid>
RPM_DISTRO ?= fedora
export VERSION RELEASE MAINTAINER RPM_DISTRO

.PHONY: help build check test stage install package package-deb package-rpm package-arch package-tarball deb rpm arch tarball clean

help:
	@echo 'make build          Build executable and fonts in bin/'
	@echo 'make check / test   Check source / run Odin tests'
	@echo 'make stage          Preview /usr package contents in bin/stage/'
	@echo 'make install        Install (supports PREFIX and DESTDIR)'
	@echo 'make package        Package for the current distro (or tarball fallback)'
	@echo 'make deb / rpm      Build DEB / RPM (RPM_DISTRO=fedora or opensuse)'
	@echo 'make arch / tarball Build Arch package / Linux tarball'
	@echo 'Outputs: bin/packages/; options: VERSION, RELEASE, ODIN, ODIN_FLAGS'

build:
	mkdir -p bin
	$(ODIN) build . -out:bin/clipboard-manager $(ODIN_FLAGS) -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
	$(PYTHON) packaging/package.py resources

check:
	$(ODIN) check . -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true

test:
	mkdir -p bin/tests
	$(ODIN) test . -out:bin/tests/app-tests -define:SQLITE3_SYSTEM_LIB=true -define:SQLITE3_DYNAMIC_LIB=true
	$(ODIN) test tray_backend -out:bin/tests/tray-tests

stage: build
	$(PYTHON) packaging/package.py stage --destdir bin/stage --prefix /usr

install: build
	$(PYTHON) packaging/package.py install --destdir "$(DESTDIR)" --prefix "$(PREFIX)"

package: build
	$(PYTHON) packaging/package.py auto

package-deb deb: build
	$(PYTHON) packaging/package.py deb

package-rpm rpm: build
	$(PYTHON) packaging/package.py rpm

package-arch arch: build
	$(PYTHON) packaging/package.py arch

package-tarball tarball: build
	$(PYTHON) packaging/package.py tarball

clean:
	$(PYTHON) packaging/package.py clean
