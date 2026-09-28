cask "deskbit" do
  version "1.3.0"
  sha256 "c16c0a08dbbcafc2ff07ab01b7ca217db5c90be01f94653b4f2d675f68777eec"

  url "https://github.com/tonyjianchina/Deskbit/releases/download/v#{version}/Deskbit-v#{version}-macOS-universal.zip"
  name "Deskbit"
  desc "Native desktop sticky notes with spatial organization"
  homepage "https://github.com/tonyjianchina/Deskbit"

  auto_updates true
  depends_on macos: :big_sur

  app "Deskbit.app"
end
