#!/usr/bin/env bash
# Shared helpers for scripts/check.sh and scripts/update.sh. Sourced, not run.

die() { echo "ERROR: $*" >&2; exit 1; }

cask_version() { # $1: cask token -> version pinned in the cask
  sed -nE 's/^[[:space:]]*version "([^"]+)".*/\1/p' "Casks/$1.rb" | head -n1
}

github_api() { # $1: URL -> body, authenticated when GH_TOKEN is set
  if [ -n "${GH_TOKEN:-}" ]; then
    curl -fsSL --retry 3 -H "Authorization: Bearer ${GH_TOKEN}" "$1"
  else
    curl -fsSL --retry 3 "$1"
  fi
}

github_tag() { # $1: owner/repo -> latest release tag, exactly as published
  github_api "https://api.github.com/repos/$1/releases/latest" |
    grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 |
    sed -E 's/.*"([^"]+)"$/\1/'
}

latest_version() { # $1: cask token -> newest upstream version
  case "$1" in
    netbird-pkg)
      local feed tag
      feed="$(curl -fsSL --retry 3 https://pkgs.netbird.io/releases/latest | tr -d '[:space:]' || true)"
      tag="$(printf '%s' "$feed" | grep -oE '"tag_name":"v[0-9.]+"' | head -n1 |
        sed -E 's/.*"v([0-9.]+)".*/\1/' || true)"
      if [ -z "$tag" ]; then # fallback: GitHub's /releases/latest redirect ends in the tag
        tag="$(curl -fsSL --retry 3 -o /dev/null -w '%{url_effective}' \
          https://github.com/netbirdio/netbird/releases/latest || true)"
        tag="${tag##*/}"
      fi
      printf '%s' "${tag#v}"
      ;;
    quickdrop)
      github_tag leonboe1/QuickDrop
      ;;
    *)
      die "unknown cask: $1"
      ;;
  esac
}

publish() { # $1: cask token, $2: version, $3: commit body
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    git config user.name "github-actions[bot]"
    git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  fi
  git add "Casks/$1.rb"
  git commit -m "$1 $2" -m "$3"
  git push
}
