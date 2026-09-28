# CoreTend 2.0 cask. The SHA-256 is filled in from Website/release.json when the DMG is
# published (Scripts/release_facts.py); until then this file is not submitted anywhere.
cask "coretend" do
  version "2.0.0"
  sha256 "RELEASE_SHA256"

  url "https://github.com/ahmetbsbnr/coretend/releases/download/v#{version}/CoreTend-#{version}-arm64.dmg",
      verified: "github.com/ahmetbsbnr/coretend/"
  name "CoreTend"
  desc "Living, local greenhouse for your Mac: see, understand, prune to the Trash"
  homepage "https://coretend.ahmetbsbnr.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "CoreTend.app"

  zap trash: [
    "~/Library/Application Support/CoreTend-Reconstruction",
    "~/Library/Preferences/com.ahmetbsbnr.coretend.plist",
  ]
end
