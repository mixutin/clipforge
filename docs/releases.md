# Releases

Clipforge ships release builds through GitHub Releases and publishes a Sparkle appcast feed on GitHub Pages.

## What The Release Automation Does

1. updates the macOS app version metadata
2. commits and tags the release
3. builds `Clipforge.app`
4. packages a `.dmg`
5. creates or updates the matching GitHub Release
6. signs the update metadata with Sparkle
7. publishes `appcast.xml` to GitHub Pages

That gives the project both a direct download in the Releases tab and a stable Sparkle feed URL for in-app updates.

## Required Repo Secret

Add this repository secret before running the release workflow:

- `SPARKLE_PRIVATE_ED_KEY`: the private Ed25519 key used by Sparkle to sign update metadata

The matching public key is already embedded in the app's `Info.plist`.

## How To Cut A Release

1. Open the `Prepare Release` workflow in GitHub Actions
2. Enter the new marketing version, for example `0.2.0`
3. Optionally provide a build number, or leave it blank to auto-increment
4. Run the workflow

That workflow updates `Clipforge/project.yml`, regenerates the Xcode project, commits the version bump, creates a `vX.Y.Z` tag, and pushes both to `main`.

The `Release` workflow then runs automatically on the new tag and publishes:

- a versioned GitHub Release
- a `.dmg` installer
- the Sparkle `appcast.xml` feed on GitHub Pages

## Feed URL

Clipforge reads updates from:

`https://mixutin.github.io/clipforge/appcast.xml`

If the repository owner or repository name changes, update the feed URL in `Clipforge/Resources/Info.plist` and in the release workflow.
