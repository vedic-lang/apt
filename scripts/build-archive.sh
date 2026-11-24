#!/usr/bin/env bash
# Build an unsigned snapshot from the reviewed upstream release assets.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
site=${1:?usage: build-archive.sh NEW_OUTPUT_DIRECTORY}
mkdir "$site"
cd "$site"
pool=pool/main/v/vedic
dist=dists/stable
index=$dist/main/binary-amd64
mkdir -p "$pool" "$index"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
while read -r tag version arch asset digest; do
    [[ -z "$tag" || "$tag" == \#* ]] && continue
    [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ && "$arch" == amd64 ]]
    [[ "$version" =~ ^[0-9][0-9A-Za-z.+~-]*$ && "$digest" =~ ^[0-9a-f]{64}$ ]]
    package="$pool/vedic_${version}_${arch}.deb"
    test ! -e "$package"
    if [[ "$asset" =~ ^source@([0-9a-f]{40})$ ]]; then
        url="https://codeload.github.com/vedic-lang/vedic/tar.gz/${BASH_REMATCH[1]}"
    else
        [[ "$asset" =~ ^[a-zA-Z0-9._-]+\.deb$ ]]
        url="https://github.com/vedic-lang/vedic/releases/download/$tag/$asset"
    fi
    curl --fail --silent --show-error --location --retry 3 "$url" -o "$scratch/input"
    echo "$digest  $scratch/input" | sha256sum --check
    if [[ "$asset" == vedic-linux-x86_64.deb ]]; then
        mv "$scratch/input" "$package"
    else
        docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
            -v "$root/packaging:/recipe:ro" -v "$scratch/input:/input:ro" -v "$PWD/$pool:/out" \
            rust:1.73.0-bookworm@sha256:e5a28b9e772535dc50205b4684b4e1cd113bb52e02e54ff387015c55c561e477 \
            /recipe/build-historical-deb.sh "$version"
        sha256sum "$package"
    fi
    test "$(dpkg-deb -f "$package" Package)" = vedic
    test "$(dpkg-deb -f "$package" Version)" = "$version"
    test "$(dpkg-deb -f "$package" Architecture)" = "$arch"
done < "$root/packages.tsv"

apt-ftparchive packages pool > "$index/Packages"
test -s "$index/Packages"
gzip -n -9 -c "$index/Packages" > "$index/Packages.gz"
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=Vedic \
    -o APT::FTPArchive::Release::Label=Vedic \
    -o APT::FTPArchive::Release::Suite=stable \
    -o APT::FTPArchive::Release::Codename=stable \
    -o APT::FTPArchive::Release::Architectures=amd64 \
    -o APT::FTPArchive::Release::Components=main \
    -o APT::FTPArchive::Release::Acquire-By-Hash=yes \
    release "$dist" > Release.new
mv Release.new "$dist/Release"
for algorithm in 256 512; do
    mkdir -p "$index/by-hash/SHA$algorithm"
    for file in "$index/Packages" "$index/Packages.gz"; do
        digest=$("sha${algorithm}sum" "$file" | cut -d' ' -f1)
        cp "$file" "$index/by-hash/SHA$algorithm/$digest"
    done
done
cp "$root/index.html" .
touch .nojekyll
