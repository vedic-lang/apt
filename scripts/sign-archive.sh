#!/usr/bin/env bash
# Sign with the local GnuPG keyring and verify against the supplied public key.
set -euo pipefail
site=${1:?usage: sign-archive.sh SITE PUBLIC_KEY}
public_key=${2:?missing public key}
release="$site/dists/stable/Release"
test -s "$release"
fingerprint=$(gpg --batch --show-keys --with-colons "$public_key" | awk -F: '$1 == "fpr" {print $10; exit}')
test -n "$fingerprint"
gpg --batch --yes --local-user "$fingerprint" --digest-algo SHA256 \
    --clearsign --output "$site/dists/stable/InRelease" "$release"
gpg --batch --yes --local-user "$fingerprint" --digest-algo SHA256 \
    --detach-sign --output "$site/dists/stable/Release.gpg" --armor "$release"
verify_dir=$(mktemp -d)
trap 'rm -rf "$verify_dir"' EXIT
gpg --batch --dearmor --output "$verify_dir/keyring.gpg" "$public_key"
gpgv --homedir "$verify_dir" --keyring "$verify_dir/keyring.gpg" "$site/dists/stable/InRelease"
gpgv --homedir "$verify_dir" --keyring "$verify_dir/keyring.gpg" "$site/dists/stable/Release.gpg" "$release"
cp "$public_key" "$site/vedic-archive-key.asc"
{
    cat <<'SOURCE'
Types: deb
URIs: https://vedic-lang.github.io/apt/
Suites: stable
Components: main
Architectures: amd64
Signed-By:
SOURCE
    sed -e 's/^$/./' -e 's/^/ /' "$public_key"
} > "$site/vedic.sources"
