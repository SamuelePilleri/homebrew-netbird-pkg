# homebrew-netbird-pkg

[![update-cask](https://github.com/SamuelePilleri/homebrew-netbird-pkg/actions/workflows/update-cask.yml/badge.svg)](https://github.com/SamuelePilleri/homebrew-netbird-pkg/actions/workflows/update-cask.yml)

A Homebrew cask wrapping NetBird's official, Apple-signed and notarized macOS
`.pkg` installer - the same package [Munki](https://github.com/munki/munki)/MDM
deploys - with a scheduled workflow that keeps it current.

## Install

```console
$ brew install --cask --adopt SamuelePilleri/netbird-pkg/netbird-pkg
```

The same command whether NetBird is already installed (Munki, NetBird's
in-app updater, manual download) or not. On an existing install, `--adopt`
registers it with Homebrew; for pkg casks Apple's installer still runs once -
an idempotent in-place reinstall at the same version. After that:

```console
$ brew update && brew upgrade
```

## Updates

A GitHub Actions workflow on a **macOS runner** checks NetBird's release feed
every six hours. On a new release it downloads both installers and, before
committing the new version and checksums to this tap, verifies that each one
is:

- signed for distribution by `Developer ID Installer: NetBird GmbH
  (TA739QLA7A)`, notarized, and accepted by Gatekeeper (`pkgutil`, `spctl`);
- the expected package - receipt `io.netbird.client` at the expected version;
- byte-identical to what `pkgs.netbird.io/macos/<arch>` serves.

The cask pins the GitHub release permalink because `pkgs.netbird.io` is only
a redirector to exactly these assets (its signed URLs expire within the
hour); older releases persist at the permalinks. On every install Homebrew
verifies the pinned sha256 and Apple's `installer` validates the signature
chain. If a check ever fails, the workflow goes red and the tap stays on the
last verified release.

## Munki

Installing or upgrading through this cask is indistinguishable from Munki
doing it - same package, same installer, same receipt. Being ahead of your
catalog is fine; Munki treats a newer installed version as installed. Check
both views with:

```console
$ pkgutil --pkg-info io.netbird.client      # what Munki reads
$ brew list --cask --versions netbird-pkg   # what Homebrew tracks
```

## Uninstall

```console
$ brew uninstall --cask netbird-pkg   # removes the receipt; Munki may reinstall
$ brew zap --cask netbird-pkg         # also removes user state and logs
```

Site configuration under `/var/lib/netbird` is never touched.

## License

MIT - see [LICENSE](LICENSE).
