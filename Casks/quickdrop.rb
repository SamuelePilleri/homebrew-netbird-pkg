cask "quickdrop" do
  version "5.1"
  sha256 "2d0bff9aa29ec7c86ac51bdd718d16afce81b374b2f0d209ac9ebf2d479eaf39"

  url "https://github.com/leonboe1/QuickDrop/releases/download/#{version}/QuickDrop.app.zip"
  name "QuickDrop"
  desc "Quick Share client"
  homepage "https://github.com/leonboe1/QuickDrop"

  livecheck do
    url "https://github.com/leonboe1/QuickDrop"
    strategy :github_latest
  end

  depends_on macos: :monterey

  app "QuickDrop.app"

  uninstall quit: "com.leonboettger.neardrop"

  zap trash: ["~/Library/Containers/com.leonboettger.neardrop",
              "~/Library/Application Scripts/com.leonboettger.neardrop",
              "~/Library/Application Scripts/group.com.leonboettger.neardrop",
              "~/Library/Group Containers/group.com.leonboettger.neardrop"]

  caveats <<~EOS
    Sandboxed app. If QuickDrop is installed from the Mac App Store, do not
    also install this cask: both use the bundle id com.leonboettger.neardrop.
  EOS
end
