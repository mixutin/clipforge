cask "clipforge" do
  version "0.5.0"
  sha256 "25adc1abce39b7fccc03de1ba5d3319839767e8658b7ff4f39de620f663cd0cb"

  url "https://github.com/mixutin/clipforge/releases/download/v#{version}/Clipforge-#{version}.dmg"
  name "Clipforge"
  desc "Native macOS capture uploader with a self-hosted FastAPI backend"
  homepage "https://github.com/mixutin/clipforge"

  auto_updates true
  depends_on macos: ">= :sequoia"

  app "Clipforge.app"
end
