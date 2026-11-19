# homebrew-tap

[![update-casks](https://github.com/SamuelePilleri/homebrew-tap/actions/workflows/update-casks.yml/badge.svg)](https://github.com/SamuelePilleri/homebrew-tap/actions/workflows/update-casks.yml)

Casks for apps that have no usable Homebrew option, kept current by a
scheduled workflow.

## netbird-pkg

NetBird's official `.pkg` ([GitHub](https://github.com/netbirdio/netbird/releases)),
wrapped so an MDM-managed install can be adopted and kept on `brew upgrade`.

Signed by NetBird GmbH (`TA739QLA7A`), receipt `io.netbird.client`; CI checks
signature, notarization and Gatekeeper on every bump.

```console
$ brew install --cask --adopt SamuelePilleri/tap/netbird-pkg
```

NetBird's official `netbirdio/tap` cask+formula install a zip + CLI and rebuild the
daemon with `netbird service install`; no `io.netbird.client` receipt is
created, so an MDM-managed install cannot be adopted.

## quickdrop

QuickDrop's `.app.zip` ([GitHub](https://github.com/leonboe1/QuickDrop/releases)).
No cask or formula upstream.

Signed by Leon Boettger (`92SDAWLN76`), bundle `com.leonboettger.neardrop`; CI
checks signature, notarization and Gatekeeper on every bump.

```console
$ brew install --cask SamuelePilleri/tap/quickdrop
```

Sandboxed; do not install alongside the Mac App Store build (same bundle id).

## Updates

A workflow checks every source every six hours on Linux. A version change
spawns one macOS runner, which downloads the release, runs the checks above,
and commits the new version and sha256. If a check fails the run goes red and
the cask stays on the last verified release.

Fully-qualified names trust just that cask (Homebrew 6+ requires third-party
taps to be trusted) and tap the repo automatically. At install time Homebrew
verifies the pinned sha256; for `.pkg` casks Apple's `installer` validates the
signature, and for `.app` casks Gatekeeper does so on first launch.
