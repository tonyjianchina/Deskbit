cask "deskbit" do
  version "1.2.2"
  sha256 "6bb9413d2ced967de2b3bc9fcf8ad8f6e210011837d9e37708a5cbb94e0db659"

  url "https://github.com/tonyjianchina/Deskbit/releases/download/v#{version}/Deskbit-v#{version}-macOS-universal.zip"
  name "Deskbit"
  desc "Native desktop sticky notes with spatial organization"
  homepage "https://github.com/tonyjianchina/Deskbit"

  depends_on macos: :big_sur

  app "Deskbit.app"
end
