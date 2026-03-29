cask "clipforge" do
  version "0.5.0"
  sha256 "a8103202ddc89b2003d22aa3a174563ca3cd24997f4de0f8bbf30da43c5f3b56"

  url "https://github.com/mixutin/clipforge/releases/download/v#{version}/Clipforge-#{version}.dmg"
  name "Clipforge"
  desc "Native macOS capture uploader with a self-hosted FastAPI backend"
  homepage "https://github.com/mixutin/clipforge"

  auto_updates true
  depends_on macos: ">= :sequoia"

  app "Clipforge.app"
end
