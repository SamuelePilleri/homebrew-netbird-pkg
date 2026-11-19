#!/usr/bin/env bash
# Bump Casks/<cask>.rb to the latest upstream release.
#
# Runs on macOS (the workflow uses a macOS runner, free for public repos) so
# every artifact is verified with Apple's own tools before the new version is
# published. No-op when the cask is already current.
#
# Usage: update.sh <cask>

set -euo pipefail
. "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")/.."

cask="${1:?usage: update.sh <cask>}"
version="$(latest_version "$cask")"
printf '%s' "$version" | grep -Eq '^[0-9][0-9.]*$' ||
  die "could not resolve a stable version (got '${version}')"

current="$(cask_version "$cask")"
echo "Latest upstream: ${version} (cask: ${current:-none})"
if [ "$version" = "$current" ]; then
  echo "Up to date; nothing to do."
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# --- netbird-pkg: official signed .pkg -------------------------------------------

verify_netbird_pkg() { # $1: arm64|amd64 -> sha256 of the verified installer
  local arch="$1"
  local name="netbird_${version}_darwin_${arch}.pkg"
  local path="${workdir}/${name}"
  curl -fsSL --retry 3 -o "$path" \
    "https://github.com/netbirdio/netbird/releases/download/v${version}/${name}"

  local sig
  sig="$(pkgutil --check-signature "$path")"
  printf '%s\n' "$sig" | grep -qF "signed by a developer certificate issued by Apple for distribution" ||
    die "${name}: not signed by a certificate trusted for distribution"
  printf '%s\n' "$sig" | grep -qF "Developer ID Installer: NetBird GmbH (TA739QLA7A)" ||
    die "${name}: not signed by NetBird GmbH (TA739QLA7A)"
  printf '%s\n' "$sig" | grep -qF "Notarization: trusted by the Apple notary service" ||
    die "${name}: not notarized"
  spctl --assess --type install "$path" >/dev/null 2>&1 || die "${name}: rejected by Gatekeeper"

  pkgutil --expand "$path" "${workdir}/x-${arch}"
  local pkginfo
  pkginfo="$(grep -h '<pkg-info' "${workdir}/x-${arch}"/*/PackageInfo)" || die "${name}: no PackageInfo"
  printf '%s\n' "$pkginfo" | grep -qF 'identifier="io.netbird.client"' ||
    die "${name}: unexpected receipt id (wanted io.netbird.client)"
  printf '%s\n' "$pkginfo" | grep -qF "version=\"${version}\"" ||
    die "${name}: unexpected package version"

  local cdn_url
  cdn_url="$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' \
    "https://pkgs.netbird.io/macos/${arch}")"
  printf '%s\n' "$cdn_url" | grep -qF "$name" ||
    die "pkgs.netbird.io serves a different file for ${arch} (CDN lag after a fresh release? the next run retries)"
  [ "$(curl -fsSL "$cdn_url" | shasum -a 256 | awk '{print $1}')" = "$(shasum -a 256 "$path" | awk '{print $1}')" ] ||
    die "${name}: not byte-identical to what pkgs.netbird.io serves"

  shasum -a 256 "$path" | awk '{print $1}'
}

update_netbird_pkg() {
  local sha_arm sha_amd
  sha_arm="$(verify_netbird_pkg arm64)"
  sha_amd="$(verify_netbird_pkg amd64)"
  echo "sha256 arm64: ${sha_arm}"
  echo "sha256 amd64: ${sha_amd}"

  sed -i '' -E \
    -e "s/^([[:space:]]*version \")[^\"]+/\1${version}/" \
    -e "s/^([[:space:]]*sha256[[:space:]]+arm:[[:space:]]+\")[0-9a-f]+/\1${sha_arm}/" \
    -e "s/^([[:space:]]*intel:[[:space:]]+\")[0-9a-f]+/\1${sha_amd}/" \
    "Casks/${cask}.rb"
  grep -qF "\"${version}\"" "Casks/${cask}.rb" &&
    grep -qF "\"${sha_arm}\"" "Casks/${cask}.rb" &&
    grep -qF "\"${sha_amd}\"" "Casks/${cask}.rb" || die "cask edit did not land"
}

# --- quickdrop: notarized .app bundle --------------------------------------------

verify_quickdrop() { # -> sha256 of the verified archive
  local name="QuickDrop.app.zip"
  local path="${workdir}/${name}"
  curl -fsSL --retry 3 -o "$path" \
    "https://github.com/leonboe1/QuickDrop/releases/download/${version}/${name}"

  # unzip, not ditto: ditto carries FinderInfo xattrs that break --strict.
  local app="${workdir}/quickdrop/QuickDrop.app"
  unzip -q "$path" -d "${workdir}/quickdrop"
  [ -d "$app" ] || die "${name}: no QuickDrop.app in the archive"

  local sig
  sig="$(codesign -dvvv "$app" 2>&1)"
  printf '%s\n' "$sig" | grep -qF "Authority=Developer ID Application: Leon Boettger (92SDAWLN76)" ||
    die "${name}: not signed by Leon Boettger (92SDAWLN76)"
  printf '%s\n' "$sig" | grep -qF "TeamIdentifier=92SDAWLN76" ||
    die "${name}: unexpected team id"
  printf '%s\n' "$sig" | grep -qF "Notarization Ticket=stapled" ||
    die "${name}: notarization ticket not stapled"
  codesign --verify --deep --strict "$app" 2>/dev/null || die "${name}: invalid code signature"
  spctl --assess --type execute "$app" >/dev/null 2>&1 || die "${name}: rejected by Gatekeeper"
  xcrun stapler validate "$app" >/dev/null 2>&1 || die "${name}: notarization ticket invalid"

  local plist="${app}/Contents/Info.plist" exe archs
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = "com.leonboettger.neardrop" ] ||
    die "${name}: unexpected bundle id (wanted com.leonboettger.neardrop)"
  [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" = "$version" ] ||
    die "${name}: unexpected app version"
  exe="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"
  archs="$(lipo -archs "${app}/Contents/MacOS/${exe}")"
  printf '%s\n' "$archs" | grep -q arm64 || die "${name}: no arm64 slice"
  printf '%s\n' "$archs" | grep -q x86_64 || die "${name}: no x86_64 slice"

  shasum -a 256 "$path" | awk '{print $1}'
}

update_quickdrop() {
  local sha
  sha="$(verify_quickdrop)"
  echo "sha256: ${sha}"

  sed -i '' -E \
    -e "s/^([[:space:]]*version \")[^\"]+/\1${version}/" \
    -e "s/^([[:space:]]*sha256 \")[0-9a-f]+/\1${sha}/" \
    "Casks/${cask}.rb"
  grep -qF "\"${version}\"" "Casks/${cask}.rb" &&
    grep -qF "\"${sha}\"" "Casks/${cask}.rb" || die "cask edit did not land"
}

# --- dispatch --------------------------------------------------------------------

case "$cask" in
  netbird-pkg)
    update_netbird_pkg
    publish "$cask" "$version" "Verified before publishing: Developer ID Installer
NetBird GmbH (TA739QLA7A), notarization, Gatekeeper, receipt io.netbird.client
${version}, byte-identical to pkgs.netbird.io."
    ;;
  quickdrop)
    update_quickdrop
    publish "$cask" "$version" "Verified before publishing: Developer ID Application
Leon Boettger (92SDAWLN76), notarization (stapled), Gatekeeper, bundle
com.leonboettger.neardrop ${version}, universal arm64 + x86_64."
    ;;
esac

echo "Published ${cask} ${version}."
