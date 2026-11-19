# homebrew-tap

[![update-casks](https://github.com/SamuelePilleri/homebrew-tap/actions/workflows/update-casks.yml/badge.svg)](https://github.com/SamuelePilleri/homebrew-tap/actions/workflows/update-casks.yml)

Casks for apps that have no usable Homebrew option, kept current by a
scheduled workflow.

| Cask | Source | Signed | Notarized | Gatekeeper | Notes |
|---|---|---|---|---|---|
| `netbird-pkg` | [NetBird](https://netbird.io) official `.pkg` (GitHub) | NetBird GmbH (`TA739QLA7A`), receipt `io.netbird.client` | ✅ | ✅ | NetBird's `netbirdio/tap` cask+formula install a zip + CLI and rebuild the daemon with `netbird service install`; no `io.netbird.client` receipt is created, so an MDM-managed install cannot be adopted. This wraps the official `.pkg`, receipt included. |
| `quickdrop` | [QuickDrop](https://github.com/leonboe1/QuickDrop) `.app.zip` (GitHub) | Leon Boettger (`92SDAWLN76`), bundle `com.leonboettger.neardrop` | ✅ | ✅ | No cask or formula upstream. Sandboxed app; do not install alongside the Mac App Store build, which uses the same bundle id. |

Fully-qualified names trust just that cask (Homebrew 6+ requires third-party
taps to be trusted) and tap the repo automatically; `--adopt` registers an
existing copy instead of refusing to install over it. Then
`brew update && brew upgrade`.

## Updates

A workflow checks every source every six hours on Linux. A version change
spawns a macOS runner, which downloads the release, runs every check in the
table above, and commits the new version and sha256. If a check fails the run
goes red and the cask stays on the last verified release.

At install time Homebrew verifies the pinned sha256; for `.pkg` casks Apple's
`installer` validates the signature, and for `.app` casks Gatekeeper does so on
first launch. Nothing unverified reaches your Mac.
