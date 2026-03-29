# Clipforge

[![CI](https://github.com/mixutin/clipforge/actions/workflows/ci.yml/badge.svg)](https://github.com/mixutin/clipforge/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/mixutin/clipforge)](./LICENSE)

Clipforge is a native macOS screenshot uploader built for speed, simplicity, and self-hosting.

Press a global hotkey, select an area of the screen, upload the screenshot to your own server, copy the returned URL, and keep moving.

## What Is Included

- `Clipforge`: a native macOS menu bar app built with Swift, SwiftUI, AppKit, and ScreenCaptureKit
- `Clipforge Server`: a small FastAPI backend for authenticated image uploads and static file serving

## Highlights

- Native macOS menu bar workflow
- Area capture and full-screen capture
- Active-window capture
- Global hotkey support
- Configurable hotkey recorder UI
- ScreenCaptureKit-based screenshots
- Bearer-token authenticated multipart uploads
- Keychain-backed API token storage
- Automatic clipboard copy of uploaded URLs, Markdown, or HTML image tags
- Configurable post-upload quick actions
- Clipboard-only capture mode when you do not want to use a server
- Drag-and-drop image uploads from Finder or other apps
- Upload progress UI for larger uploads
- Optional annotation review with arrows, boxes, highlights, and freehand pen markup
- Local recent upload history
- Thumbnail previews in recent uploads
- Local-first settings
- Sparkle-powered in-app update checks
- Self-hosted backend with local disk storage
- Optional Open Graph share pages for cleaner Discord-style embeds
- Permissive open-source licensing

## Repo Layout

```text
.
├── Clipforge/        # macOS app
├── ClipforgeServer/  # FastAPI backend
├── docs/             # project documentation
└── .github/          # CI, issue templates, repo automation
```

## Quick Start

### 1. Run Clipforge Server

```bash
cd ClipforgeServer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --env-file .env
```

### 2. Run The macOS App

```bash
cd Clipforge
xcodegen generate
open Clipforge.xcodeproj
```

Build and run the `Clipforge` scheme, then configure:

- server URL, for example `http://127.0.0.1:8000`
- API token matching your server config

## Product Flow

1. Launch Clipforge into the menu bar
2. Trigger `Capture Area` from the popover or with the global hotkey
3. Drag to select a region
4. Clipforge captures the image with ScreenCaptureKit
5. The image uploads to your self-hosted server
6. The server returns a public URL
7. Clipforge copies the URL to the clipboard and shows a success toast

## Documentation

- [Agent Guide](./AGENTS.md)
- [Architecture](./docs/architecture.md)
- [Self-Hosting Guide](./docs/self-hosting.md)
- [Project TODO](./TODO.md)
- [Release Guide](./docs/releases.md)
- [Contributing](./CONTRIBUTING.md)
- [Security Policy](./SECURITY.md)

## Permissions

Clipforge requires Screen Recording permission on macOS to capture screenshots.

If access is denied:

- Open `System Settings`
- Go to `Privacy & Security`
- Open `Screen Recording`
- Enable Clipforge

## Open Source License

Clipforge is licensed under the Apache License 2.0.

That keeps the project fully open-source and broadly reusable while also providing an explicit patent grant, which is a strong default for a public developer tool.
