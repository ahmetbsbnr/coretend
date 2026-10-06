cask "coretend" do
  version "2.1.2"
  sha256 "10e9a45b9f540fdbd7fe9a45e8574ecfbd6af7fe47fb4d9bfda2b66d020f99f7"

  url "https://github.com/ahmetbsbnr/coretend/releases/download/v#{version}/CoreTend-#{version}-arm64.zip"
  name "CoreTend"
  desc "See what fills the disk and clear it safely, to the Trash"
  homepage "https://coretend.ahmetbsbnr.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "CoreTend.app"
  binary "#{appdir}/CoreTend.app/Contents/Helpers/coretend"

  zap trash: [
    "~/Library/Application Support/CoreTend-Reconstruction",
    "~/Library/Caches/com.ahmetbsbnr.coretend",
    "~/Library/HTTPStorages/com.ahmetbsbnr.coretend",
    "~/Library/Preferences/com.ahmetbsbnr.coretend.plist",
  ]
end
