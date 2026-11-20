cask "netbird-pkg" do
  arch arm: "arm64", intel: "amd64"

  version "0.83.2"
  sha256 arm:   "6e98d0dc338f5d6635f8803c1afaa765b12000b30f7e9ec04d0ab8d103570020",
         intel: "3eae9982cc169854ce55aaed175a28980666fc922874b602be39878916891a8e"

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
