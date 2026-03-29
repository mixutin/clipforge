# Architecture

Clipforge is intentionally split into two small, focused components.

## 1. Clipforge macOS App

The macOS app is a lightweight menu bar utility.

### Responsibilities

- expose a menu bar popover UI
- trigger screenshot capture from the menu bar or global hotkey
- collect screenshots with ScreenCaptureKit
- upload images to the configured self-hosted server
- copy the returned URL to the clipboard
- persist local settings and recent upload history

### Technology Choices

- `SwiftUI` for settings and popover content
- `AppKit` for `NSStatusItem`, `NSPopover`, overlay windows, and floating toast panels
- `Carbon` for a reliable global hotkey implementation
- `ScreenCaptureKit` for modern macOS-native screenshot capture
- `Sparkle` for GitHub-backed in-app updates
- `UserDefaults` and JSON files for local-first persistence

## 2. Clipforge Server

Clipforge Server is a simple authenticated upload service.

### Responsibilities

- accept multipart image uploads
- validate file type and enforce size limits
- save uploads to local disk
- return a public URL in JSON
- serve uploaded files statically

### Technology Choices

- `FastAPI` for a small, explicit HTTP API
- local disk storage for MVP simplicity
- bearer-token auth for a minimal secure upload flow

## Integration Contract

The server exposes:

- `GET /health`
- `POST /upload`
- `GET /uploads/<filename>`

The app sends:

- `Authorization: Bearer <token>`
- multipart form-data field named `file`

The server returns:

```json
{
  "url": "https://example.com/uploads/abc123.png"
}
```

## Design Principles

- native-feeling over cross-platform abstraction
- self-hosting simplicity over infrastructure sprawl
- local-first configuration over accounts and dashboards
- modular code over premature complexity

## Release Distribution

GitHub Actions produces tagged release builds for the macOS app, packages them as `.dmg` installers, publishes them on GitHub Releases, and generates a Sparkle appcast feed on GitHub Pages.
