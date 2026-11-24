#!/usr/bin/env bash
# Test the actual Debian client in clean amd64 systems. Pass a site directory or "live".
set -euo pipefail
target=${1:?usage: test-install.sh SITE_DIRECTORY_OR_live}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mounts=()
expected_versions=
if [[ "$target" == live ]]; then
    curl --fail --silent --show-error --location --retry 3 \
        https://vedic-lang.github.io/apt/vedic.sources -o "$scratch/vedic.sources"
    # Verify the exact certificate APT will trust, independently of the site.
    sed -n '/^Signed-By:$/,$p' "$scratch/vedic.sources" | tail -n +2 |
        sed -e 's/^ //' -e 's/^\.$//' > "$scratch/archive.asc"
    cmp "$(dirname "$0")/../vedic-archive-key.asc" "$scratch/archive.asc"
else
    expected_versions=$(awk '!/^#/ && NF { print $2 }' "$(dirname "$0")/../packages.tsv" | sort -V)
    site=$(cd "$target" && pwd)
    mounts=(-v "$site:/archive:ro")
    sed 's|^URIs: .*|URIs: file:/archive|' "$site/vedic.sources" > "$scratch/vedic.sources"
fi
chmod 644 "$scratch/vedic.sources"
for distro in debian:13-slim ubuntu:24.04; do
    echo "Testing $target on $distro"
    docker run --rm --platform linux/amd64 -i "${mounts[@]}" \
        -e "EXPECTED_VERSIONS=$expected_versions" \
        -v "$scratch/vedic.sources:/etc/apt/sources.list.d/vedic.sources:ro" "$distro" bash -se <<'TEST'
export DEBIAN_FRONTEND=noninteractive
if ! test -s /etc/ssl/certs/ca-certificates.crt && grep -q 'URIs: https:' /etc/apt/sources.list.d/vedic.sources; then
    # Bootstrap HTTPS using the distribution's own archive.
    distro_source=$(find /etc/apt/sources.list.d -name '*.sources' ! -name vedic.sources -print -quit)
    apt-get -o Dir::Etc::sourcelist="$distro_source" -o Dir::Etc::sourceparts=- update
    apt-get -o Dir::Etc::sourcelist="$distro_source" -o Dir::Etc::sourceparts=- install -y ca-certificates
fi
options=(-o Dir::Etc::sourcelist=/etc/apt/sources.list.d/vedic.sources -o Dir::Etc::sourceparts=-)
apt-get "${options[@]}" --error-on=any update
versions=$(apt-cache "${options[@]}" madison vedic | awk '{print $3}' | sort -Vu)
test -n "$versions"
if [[ -n "$EXPECTED_VERSIONS" ]]; then test "$versions" = "$EXPECTED_VERSIONS"; fi

printf 'वद("नमस्ते विश्व!");\n' > /tmp/hello.ved
check_install() {
    local version=$1
    test "$(dpkg-query -W -f='${Version}' vedic)" = "$version"
    test "$(vedic --version)" = "Vedic v${version%-*}"
    test "$(vedic /tmp/hello.ved)" = 'नमस्ते विश्व!'
    printf 'Installed vedic %s and ran Hello World.\n' "$version"
}

current=$(tail -n 1 <<< "$versions")
apt-get "${options[@]}" install -y vedic
check_install "$current"
while IFS= read -r version; do
    if [[ "$version" == "$current" ]]; then continue; fi
    apt-get "${options[@]}" install -y --allow-downgrades "vedic=$version"
    check_install "$version"
done <<< "$versions"
TEST
done
