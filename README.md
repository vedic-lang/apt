# Vedic APT repository

Install the Vedic CLI on amd64 (Intel/AMD 64-bit) Debian 13 and Ubuntu 24.04. The archive distributes packages from the [official Vedic releases](https://github.com/vedic-lang/vedic/releases), including corrected revisions of three historical releases. Vedic 2.1.0 requires glibc 2.38 or newer.

## Install

Download the deb822 source file. Its embedded public key scopes trust to the Vedic repository.

```sh
curl -fsSLo vedic.sources https://vedic-lang.github.io/apt/vedic.sources
sudo install -m 0644 vedic.sources /etc/apt/sources.list.d/vedic.sources
sudo apt update
sudo apt install vedic
vedic --version
```

Vedic 3.0 uses `आवाहन` for file imports. When upgrading a 2.x program, replace each `अवहन` import with `आवाहन`.

APT includes Vedic in subsequent upgrades. To remove this source, run `sudo rm /etc/apt/sources.list.d/vedic.sources` and `sudo apt update`.

**Archive key fingerprint** `0127 717E 292B 79AB 37A4 2569 1896 6A86 0792 F8D9`. Inspect the [public key](./vedic-archive-key.asc) with `gpg --show-keys --fingerprint vedic-archive-key.asc`.

## Find older versions

After updating the package lists, run `apt-cache madison vedic` to see the versions available from APT. For example, on a fresh system, `sudo apt install vedic=2.0.6-1` selects the 2.0.6 release. A plain `sudo apt install vedic` selects the latest candidate.

### Corrected historical packages

On a fresh amd64 installation, choose any of these versions by its full Debian version. For example, run `sudo apt install vedic=1.2.2-1`.

| Debian version | Package contents |
| --- | --- |
| `2.0.5-1` | Built from the [v2.0.5 source](https://github.com/vedic-lang/vedic/tree/bc104d81759fb56e26f4d968aa087936ce37056c), with the CLI version updated from 2.0.4 to 2.0.5 in the Cargo manifest and lockfile. |
| `1.2.2-1` | The original [v1.2.2 executable](https://github.com/vedic-lang/vedic/releases/tag/v1.2.2), packaged as `vedic` for amd64. It replaces the historical `vedic-lang` package. |
| `1.2.0-1` | The original [v1.2.0 executable](https://github.com/vedic-lang/vedic/releases/tag/v1.2.0), packaged for amd64. |

All three install `/usr/bin/vedic`. The 1.x CLI reports its version as `v1.2.x`. For Hello World, use `वद् "नमस्ते विश्व!";` in 1.2.0 and `वद "नमस्ते विश्व!";` in 1.2.2.

## Publish a release

1. Add a row to [packages.tsv](./packages.tsv) with the upstream release tag, exact Debian package version, architecture, asset name and SHA-256 from the release. Retain previous versions and use a new Debian revision when package bytes change.
   For the corrected revisions, the manifest also pins the finished `.deb` SHA-256. The [packaging recipe](./packaging/build-historical-deb.sh) uses a digest-pinned amd64 build image and fixed timestamps. The 2.0.5 source entry identifies the release commit.
2. Open a PR. CI downloads the pinned assets, validates their hashes and Debian control fields, creates APT indexes and installs the signed candidate in clean Debian and Ubuntu containers. Each test runs `vedic --version` and a Sanskrit Hello World program.
3. Merging to `main` signs the tested indexes with the `APT_SIGNING_SUBKEY` environment secret, updates the publication branch `gh-pages`, requests a Pages build and checks installations over HTTPS. The `apt-signing` environment is restricted to the `main` branch. GitHub Pages serves the root of `gh-pages`.
4. To exercise the published archive independently, add the `verify-live` label to an open PR. To republish the reviewed manifest, run the **Vedic APT archive** workflow on `main`.

The primary certification key stays with the maintainer. Renew or replace the signing subkey before **2029-11-23**. Distribute the refreshed public certificate to clients before the current subkey expires, update the committed public key, and install the corresponding secret subkey in `apt-signing`.
