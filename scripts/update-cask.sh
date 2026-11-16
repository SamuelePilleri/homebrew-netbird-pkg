#!/usr/bin/env bash
#
# Bump Casks/netbird-pkg.rb to the latest NetBird release.
#
# Runs on macOS (the workflow uses a macOS runner, free for public repos) so
# every installer is verified with Apple's own tools before the new version
# is published: distribution signature from NetBird GmbH, notarization,
# Gatekeeper, package identity, and byte-identity with pkgs.netbird.io.
# No-op when the cask is already current.

set -euo pipefail

CASK="Casks/netbird-pkg.rb"
TEAM="Developer ID Installer: NetBird GmbH (TA739QLA7A)"
RECEIPT="io.netbird.client"
GITHUB="https://github.com/netbirdio/netbird/releases"
CDN="https://pkgs.netbird.io/macos"
FEED="https://pkgs.netbird.io/releases/latest"

cd "$(dirname "$0")/.."
die() { echo "ERROR: $*" >&2; exit 1; }

# --- resolve the latest upstream release ----------------------------------------

tag="$(
  curl -fsSL --retry 3 "$FEED" | tr -d '[:space:]' |
    grep -oE '"tag_name":"v[0-9.]+"' | head -n1 | grep -oE 'v[0-9.]+' || true
)"
if [ -z "$tag" ]; then # fallback: GitHub's /releases/latest redirect ends in the tag
  tag="$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "${GITHUB}/latest")"
  tag="${tag##*/}"
fi
version="${tag#v}"
printf '%s' "$version" | grep -Eq '^[0-9][0-9.]*$' || die "could not resolve a stable version (got '${tag:-}')"

current="$(sed -nE 's/^[[:space:]]*version "([^"]+)".*/\1/p' "$CASK" | head -n1)"
echo "Latest upstream: ${tag} (cask: ${current:-none})"
if [ "$version" = "$current" ]; then
  echo "Up to date; nothing to do."
  exit 0
fi

# --- download and verify both installers ------------------------------------------

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

verify() { # $1: arm64|amd64 - prints the verified pkg's sha256 on stdout
  local arch="$1"
  local name="netbird_${version}_darwin_${arch}.pkg"
  local path="${workdir}/${name}"
  curl -fsSL --retry 3 -o "$path" "${GITHUB}/download/v${version}/${name}"

  local sig
  sig="$(pkgutil --check-signature "$path")"
  printf '%s\n' "$sig" | grep -qF "signed by a developer certificate issued by Apple for distribution" ||
    die "${name}: not signed by a certificate trusted for distribution"
  printf '%s\n' "$sig" | grep -qF "$TEAM" || die "${name}: not signed by ${TEAM}"
  printf '%s\n' "$sig" | grep -qF "Notarization: trusted by the Apple notary service" || die "${name}: not notarized"
  spctl --assess --type install "$path" >/dev/null 2>&1 || die "${name}: rejected by Gatekeeper"

  local pkginfo
  pkgutil --expand "$path" "${workdir}/x-${arch}"
  pkginfo="$(grep -h '<pkg-info' "${workdir}/x-${arch}"/*/PackageInfo)" || die "${name}: no PackageInfo"
  printf '%s\n' "$pkginfo" | grep -qF "identifier=\"${RECEIPT}\"" || die "${name}: unexpected receipt id (wanted ${RECEIPT})"
  printf '%s\n' "$pkginfo" | grep -qF "version=\"${version}\"" || die "${name}: unexpected package version"

  local cdn_url
  cdn_url="$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' "${CDN}/${arch}")"
  printf '%s\n' "$cdn_url" | grep -qF "$name" ||
    die "pkgs.netbird.io serves a different file for ${arch} (CDN lag after a fresh release? the next run retries)"
  [ "$(curl -fsSL "$cdn_url" | shasum -a 256 | awk '{print $1}')" = "$(shasum -a 256 "$path" | awk '{print $1}')" ] ||
    die "${name}: not byte-identical to what pkgs.netbird.io serves"

  shasum -a 256 "$path" | awk '{print $1}'
}

sha_arm="$(verify arm64)"
sha_amd="$(verify amd64)"
echo "sha256 arm64: ${sha_arm}"
echo "sha256 amd64: ${sha_amd}"

# --- update the cask (BSD sed; the script only targets macOS) ---------------------

sed -i '' -E \
  -e "s/^([[:space:]]*version \")[^\"]+/\1${version}/" \
  -e "s/^(sha256[[:space:]]+arm:[[:space:]]+\")[0-9a-f]+/\1${sha_arm}/" \
  -e "s/^([[:space:]]*intel:[[:space:]]+\")[0-9a-f]+/\1${sha_amd}/" \
  "$CASK"
grep -qF "\"${version}\"" "$CASK" &&
grep -qF "\"${sha_arm}\"" "$CASK" &&
grep -qF "\"${sha_amd}\"" "$CASK" || die "cask edit did not land"

# --- publish -----------------------------------------------------------------------

if [ -n "${GITHUB_ACTIONS:-}" ]; then
  git config user.name  "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi
git commit -am "netbird-pkg ${version}

Verified before publishing: ${TEAM}, notarization, Gatekeeper,
receipt ${RECEIPT} ${version}, byte-identical to pkgs.netbird.io."
git push
echo "Published netbird-pkg ${version}."
