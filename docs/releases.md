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

## Optional Notarization Secrets

If you want release builds to be Developer ID signed, notarized, and stapled automatically, also add:

- `APPLE_DEVELOPER_ID_CERT_P12_BASE64`: base64-encoded `.p12` certificate export
- `APPLE_DEVELOPER_ID_CERT_PASSWORD`: password for the `.p12`
- `APPLE_DEVELOPER_ID_APPLICATION`: full Developer ID Application identity name used by `codesign`
- `APPLE_NOTARY_APPLE_ID`: Apple ID used for notarization
- `APPLE_NOTARY_APP_SPECIFIC_PASSWORD`: app-specific password for the Apple ID
- `APPLE_TEAM_ID`: Apple Developer team identifier

When those secrets are present, the `Release` workflow:

1. imports the signing certificate into a temporary keychain
2. signs `Clipforge.app` and the generated `.dmg`
3. submits the `.dmg` to Apple notarization
4. staples the notarization ticket back onto the app and `.dmg`
5. verifies the stapled installer with `spctl`

If the notarization secrets are missing, the workflow still builds the `.dmg`, updates GitHub Releases, and publishes the Sparkle feed. It just skips Apple signing and notarization.

## How To Cut A Release

1. Open the `Prepare Release` workflow in GitHub Actions
2. Enter the new marketing version, for example `0.2.0`
3. Optionally provide a build number, or leave it blank to auto-increment
4. Run the workflow

That workflow updates `Clipforge/project.yml`, regenerates the Xcode project, commits the version bump, creates a `vX.Y.Z` tag, pushes both to `main`, and dispatches the `Release` workflow for that tag.

The `Release` workflow then publishes:

- a versioned GitHub Release
- a `.dmg` installer
- the Sparkle `appcast.xml` feed on GitHub Pages

## Feed URL

Clipforge reads updates from:

`https://mixutin.github.io/clipforge/appcast.xml`

If the repository owner or repository name changes, update the feed URL in `Clipforge/Resources/Info.plist` and in the release workflow.
