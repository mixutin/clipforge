# Install Guide

Clipforge ships as a signed macOS `.dmg` through GitHub Releases and can also be packaged with Homebrew Cask.

## Standalone `.dmg`

This is the easiest path for most people.

1. Open the latest [GitHub Release](https://github.com/mixutin/clipforge/releases/latest)
2. Download `Clipforge-<version>.dmg`
3. Open the disk image
4. Drag `Clipforge.app` into `Applications`
5. Launch Clipforge from `Applications`
6. If macOS warns about a downloaded app, use `Open` once from Finder or `System Settings > Privacy & Security`

After that, Clipforge can keep itself current through the built-in Sparkle updater.

## Homebrew

This repository includes a reusable cask definition workflow, but it is not a dedicated `homebrew-...` tap repository.

The simplest Homebrew-based install flow today is:

1. Clone this repository
2. `cd packaging/homebrew`
3. Update the `sha256` in `clipforge.rb` to match the release you want to install
4. Run:

   ```bash
   brew install --cask ./clipforge.rb
   ```

If you want to publish Clipforge through your own Homebrew tap:

1. Create a tap repository such as `homebrew-clipforge`
2. Copy `packaging/homebrew/clipforge.rb` into that repo's `Casks/` directory
3. Update `version`, `sha256`, and the release URL for each new version
4. Users can then install with:

   ```bash
   brew tap <owner>/clipforge
   brew install --cask clipforge
   ```

## Verifying a Release Asset

To calculate the SHA-256 for a released `.dmg`:

```bash
shasum -a 256 Clipforge-0.5.0.dmg
```

Use that hash in the Homebrew cask file before publishing a new tap update.
