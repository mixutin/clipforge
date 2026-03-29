# Clipforge

Clipforge is a native macOS menu bar screenshot uploader that captures with ScreenCaptureKit, uploads to your own Clipforge Server, copies the returned URL, and keeps a lightweight local upload history.

## Features

- Menu bar app with a native AppKit status item and SwiftUI popover
- Global hotkey for area capture
- Area selection overlay with dimmed screen and drag-to-select flow
- Full-screen capture of the display under the cursor
- Active-window capture
- Clipboard image upload
- Clipboard image and copied image-file paste with `Command-V`
- Drag-and-drop image upload inside the menu bar popover
- Clipboard-only capture mode when no server is configured
- Bearer-token authenticated multipart uploads
- Configurable URL, Markdown, or HTML copy formats for uploads
- Upload progress UI in the menu bar popover
- Optional annotation editor before upload or clipboard copy
- Local history and optional local screenshot saving
- Configurable post-upload quick actions
- Small floating success and error toast panels
- Sparkle-powered in-app update checks

## Project Layout

- `project.yml`: XcodeGen project definition
- `Sources/`: Swift source files
- `Resources/Info.plist`: menu bar app configuration and ATS setting

## Setup

1. Install Xcode 15.2 or newer and XcodeGen.
2. From this folder run:

   ```bash
   xcodegen generate
   open Clipforge.xcodeproj
   ```

3. Build and run the `Clipforge` scheme.
4. Open `Clipforge > Settings` from the menu bar popover.
5. Fill in:
   - server URL, for example `http://127.0.0.1:8000`
   - API token matching your Clipforge Server
6. Trigger a capture from the menu bar or with the default hotkey `Command + Shift + 6`.

## Permissions

Clipforge needs Screen Recording permission to capture screenshots with ScreenCaptureKit. The app prompts for access the first time you try to capture. If macOS denies access, open:

- System Settings
- Privacy & Security
- Screen Recording

## AppKit Usage

SwiftUI powers the popover and settings UI, while AppKit is used where macOS-native control matters:

- `NSStatusItem` and `NSPopover` for the menu bar presence
- Carbon `RegisterEventHotKey` for a reliable global hotkey
- Borderless `NSWindow` overlays for region selection
- Floating `NSPanel` toasts for success and error feedback

## Updates

Clipforge includes a built-in `Check for Updates…` action powered by Sparkle.

Release builds look for updates at:

`https://mixutin.github.io/clipforge/appcast.xml`

## Info.plist And Entitlements

- `LSUIElement = YES` keeps Clipforge out of the Dock and menu bar focused
- `NSAllowsArbitraryLoads = YES` makes local HTTP self-hosting practical for MVP use
- No special entitlements are required for local development or non-App-Store distribution
