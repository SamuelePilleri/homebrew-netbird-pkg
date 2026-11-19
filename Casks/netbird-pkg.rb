cask "netbird-pkg" do
  arch arm: "arm64", intel: "amd64"

  version "0.83.1"
  sha256 arm:   "a96e402ba31ff4804a88ad04fac2e3f9e695f0e80440f39a68c2cb3f661a0d2a",
         intel: "ed27bd225a15a9d62a682ffdaa2093e4ba72126d335fecf65b972d7b3db44e92"

  # pkgs.netbird.io/macos/#{arch} only 302-redirects (with ~1h expiring signed
  # URLs) to this exact GitHub-hosted release asset, so the permalink below is
  # the only stable, version-pinned URL for the official signed .pkg. The
  # update-cask workflow verifies every release before it lands here.
  url "https://github.com/netbirdio/netbird/releases/download/v#{version}/netbird_#{version}_darwin_#{arch}.pkg"
  name "NetBird"
  desc "Connect private networks securely over a WireGuard-based mesh VPN"
  homepage "https://netbird.io/"

  livecheck do
    url "https://pkgs.netbird.io/releases/latest"
    regex(/"tag_name":\s*"v(\d+(?:\.\d+)+)"/i)
  end

  depends_on :macos

  pkg "netbird_#{version}_darwin_#{arch}.pkg"

  # "netbird" is the LaunchDaemon label the package installs.
  uninstall launchctl: "netbird",
            quit:      "io.netbird.client",
            pkgutil:   "io.netbird.client"

  # /var/lib/netbird (site configuration) is deliberately never removed.
  zap delete: ["/var/log/netbird",
               "/var/log/netbird.err.log",
               "/var/log/netbird.out.log"],
      trash:  "~/Library/Application Support/netbird"

  caveats <<~EOS
    Official Apple-signed, notarized installer; preserves the io.netbird.client
    receipt used by Munki/MDM.
  EOS
end
