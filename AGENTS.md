# AGENTS

This repository contains two products that evolve together:

- `Clipforge/`: the native macOS menu bar app
- `ClipforgeServer/`: the self-hosted FastAPI backend

Agents working in this repo should treat existing shipped behavior as product requirements, not disposable implementation details.

## Core Rule

Updates should extend or refine Clipforge. They should not silently remove, replace, or regress features that already exist unless the user explicitly asks for a removal or redesign.

If a planned change conflicts with an existing feature, stop and preserve both behaviors if possible. If that is not possible, call out the tradeoff before making the change.

## Product Guardrails

Keep these principles intact:

- Keep the app fast, minimal, native-feeling, and dark-mode friendly
- Keep Clipforge as a menu bar app, not a large dock-first app
- Keep the backend easy to self-host and simple to understand
- Prefer local-first settings over cloud accounts or dashboards
- Prefer additive MVP-friendly changes over large rewrites
- Keep dependencies minimal unless there is a clear payoff

## Shipped Features That Must Not Be Accidentally Removed

### macOS App

- Menu bar app with popover UI
- Area capture
- Full-screen capture
- Active-window capture
- Scroll capture for long pages
- Short screen clip recording and upload
- Global hotkey support with configurable recorder UI
- Clipboard-only capture mode
- Automatic fallback to clipboard mode when no server is configured
- Server upload flow with bearer token auth
- Multiple named server profiles with one active upload target
- Automatic copy of uploaded URL to clipboard when enabled
- OCR text recognition with copy actions for captured images
- Drag-and-drop image upload support in the menu bar popover
- Clipboard image upload
- Recent uploads with thumbnail previews
- Local history persistence
- Local screenshot saving
- Optional reveal of the saved file in Finder after upload
- Retry and recovery UX for temporary upload failures
- First-run permission onboarding for Screen Recording
- Sparkle-based update checks

### Backend

- `GET /health`
- `POST /upload`
- Static serving from `/uploads`
- Bearer token protection for uploads
- Multipart upload handling
- File type validation for images and short video clips
- File-signature validation
- Max upload size enforcement
- Local disk storage
- Upload deletion with token auth
- Optional Open Graph share pages for embeds
- Optional share-page metadata for video uploads
- CORS disabled by default unless configured

When changing related code, verify that these behaviors still make sense together.

## Repository Map

### macOS App

- `Clipforge/Sources/App/`: app lifecycle, app controller, onboarding controller
- `Clipforge/Sources/MenuBar/`: status item and popover UI
- `Clipforge/Sources/Capture/`: ScreenCaptureKit capture services and selection overlay
- `Clipforge/Sources/Settings/`: settings store and settings UI
- `Clipforge/Sources/Upload/`: upload client and multipart builder
- `Clipforge/Sources/Utilities/`: hotkey, keychain, clipboard, history, updater, toast, helpers
- `Clipforge/Sources/Views/`: shared SwiftUI views
- `Clipforge/Tests/`: macOS unit tests

### Backend

- `ClipforgeServer/app/main.py`: app bootstrap, middleware, mounts
- `ClipforgeServer/app/routes/`: HTTP routes
- `ClipforgeServer/app/utils/`: file and share helpers
- `ClipforgeServer/tests/`: backend tests

### Project Metadata

- `Clipforge/project.yml`: XcodeGen source of truth for the macOS project
- `Clipforge/Clipforge.xcodeproj/`: generated project files
- `.github/workflows/`: CI and release automation

## Xcode Project Rule

Do not treat `Clipforge/Clipforge.xcodeproj/project.pbxproj` as the source of truth.

If you add, remove, or reorganize app files, update `Clipforge/project.yml` first and then regenerate the project with:

```bash
cd Clipforge
xcodegen generate
```

Only modify the generated Xcode project directly when there is no practical alternative.

## Change Strategy

When implementing features:

- Prefer focused edits over broad rewrites
- Reuse existing services before introducing new abstraction layers
- Keep existing settings and user flows working
- Preserve backward compatibility in stored settings and history where practical
- Preserve current server API behavior unless the user asks for a contract change
- If you add a new setting, give it a safe default that does not break current users
- If you change copy or UI behavior, keep the fast one-click flow intact

## Security And Data Handling

- Never hardcode API tokens, signing keys, or secrets
- Keep the macOS app token in Keychain, not `UserDefaults`
- Keep server auth on `POST /upload`
- Do not weaken upload validation, size enforcement, or default CORS behavior without explicit direction
- If you add new upload or share behavior, think through abuse, file validation, and privacy impact
- If you touch release automation, preserve Sparkle signing and the optional notarization path

## Validation Expectations

For macOS app changes, run:

```bash
xcodebuild -project Clipforge/Clipforge.xcodeproj -scheme Clipforge -configuration Debug -destination 'platform=macOS' test
```

For backend changes, run:

```bash
cd ClipforgeServer
source .venv/bin/activate
pytest -q
```

If you touch both sides, run both.

If a change affects release, updater, or packaging behavior, also inspect:

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`
- `docs/releases.md`

## Documentation Expectations

Update docs when behavior changes:

- `README.md` for top-level product behavior
- `Clipforge/README.md` for macOS app setup or capabilities
- `ClipforgeServer/README.md` for backend setup or API behavior
- `TODO.md` to mark completed roadmap items or add new follow-up work

## Preferred Implementation Style

### Swift

- Use SwiftUI where it fits naturally
- Use AppKit where native macOS behavior requires it
- Keep code modular and production-minded
- Avoid unnecessary view-model sprawl for small features

### Python

- Keep FastAPI code explicit and lightweight
- Favor small helpers and clear route logic over framework-heavy patterns
- Keep the backend easy to read and easy to self-host

## Before Finishing Work

Before calling a task done, quickly sanity-check:

- Does this preserve existing Clipforge behavior?
- Did I accidentally remove or bypass a shipped feature?
- Did I keep the menu bar workflow lightweight?
- Did I keep the server simple and self-hostable?
- Did I run the relevant tests?
- Did I update docs if user-facing behavior changed?

If the answer to any of those is no, fix that before wrapping up.
