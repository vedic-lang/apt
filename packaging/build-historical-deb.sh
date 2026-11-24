#!/usr/bin/env bash
# Runs inside the pinned amd64 build image. /input is verified by build-archive.sh.
set -euo pipefail
umask 022
export LC_ALL=C TZ=UTC
version=${1:?missing Debian version}
mkdir -p /tmp/vedic-build
cd /tmp/vedic-build
mkdir -p pkg/DEBIAN pkg/usr/bin pkg/usr/share/doc/vedic
case "$version" in
    1.2.0-1|1.2.2-1)
        if [[ "$version" == 1.2.0-1 ]]; then
            export SOURCE_DATE_EPOCH=1650780943
        else
            export SOURCE_DATE_EPOCH=1665085170
        fi
        dpkg-deb -x /input original
        install -m 0755 original/usr/local/bin/vedic pkg/usr/bin/vedic
        install -m 0644 /recipe/LICENSE-1.x pkg/usr/share/doc/vedic/copyright
        ;;
    2.0.5-1)
        export SOURCE_DATE_EPOCH=1697616833
        mkdir source
        tar -xzf /input -C source --strip-components=1
        (
            cd source
            # The v2.0.5 tag still has the v2.0.4 CLI manifest and lockfile entry.
            sed -i '/^\[package\]$/,/^\[/s/^version = "2.0.4"$/version = "2.0.5"/' cli/Cargo.toml
            sed -i '/^name = "vedic"$/,+1s/^version = "2.0.4"$/version = "2.0.5"/' Cargo.lock
            export RUSTUP_TOOLCHAIN=1.73.0 CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER=cc
            cargo build --locked --release --package vedic
            strip --strip-unneeded target/release/vedic
        )
        install -m 0755 source/target/release/vedic pkg/usr/bin/vedic
        install -m 0644 source/LICENSE pkg/usr/share/doc/vedic/copyright
        install -m 0644 source/README.md pkg/usr/share/doc/vedic/README
        ;;
    *) echo "Unknown historical package revision: $version" >&2; exit 1 ;;
esac

# Derive runtime library dependencies from the executable's imported symbols.
mkdir debian
printf 'Source: vedic\n\nPackage: vedic\nArchitecture: amd64\n' > debian/control
deps=$(dpkg-shlibdeps -O -epkg/usr/bin/vedic)
cat > pkg/DEBIAN/control <<CONTROL
Package: vedic
Version: $version
Architecture: amd64
Section: interpreters
Priority: optional
Maintainer: Pt. Prashant Tripathi <ptprashanttripathi@outlook.com>
Depends: ${deps#shlibs:Depends=}
Conflicts: vedic-lang (<= 1.2.2)
Replaces: vedic-lang (<= 1.2.2)
Description: Sanskrit programming language interpreter
CONTROL
find pkg -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
dpkg-deb --build --root-owner-group --threads-max=1 -Zxz -z6 pkg "/out/vedic_${version}_amd64.deb"
