#!/usr/bin/env bash
# Report whether upstream has a newer release than Casks/<cask>.rb pins.
# Linux-safe: used by the workflow's check jobs, so no Apple tooling.
#
# Usage: check.sh <cask>   -> prints "update=true|false", sets the step output.

set -euo pipefail
. "$(dirname "$0")/lib.sh"

cask="${1:?usage: check.sh <cask>}"
version="$(latest_version "$cask")"
printf '%s' "$version" | grep -Eq '^[0-9][0-9.]*$' ||
  die "could not resolve a stable version for ${cask} (got '${version}')"

current="$(cask_version "$cask")"
echo "upstream ${version} | cask ${current:-none}"
if [ "$version" = "$current" ]; then update=false; else update=true; fi
echo "update=${update}"
[ -z "${GITHUB_OUTPUT:-}" ] || echo "update=${update}" >> "$GITHUB_OUTPUT"
