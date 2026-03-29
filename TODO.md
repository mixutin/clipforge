# TODO

This file tracks practical next steps for turning Clipforge from a strong MVP into a more complete product.

The list is intentionally opinionated:

- keep the app fast and native-feeling
- keep the server simple to self-host
- prefer product value over infrastructure sprawl

## Now

## Recently Completed

- [x] Add a searchable upload history view outside the compact menu bar list
- [x] Add richer filename templates with placeholders like date, time, display name, and random suffix
- [x] Add optional JPEG/PNG compression settings in the app
- [x] Add clipboard image polling or a paste action for faster non-screenshot uploads
- [x] Add image annotation tools before upload
- [x] Add drag-and-drop image upload support to the menu bar popover
- [x] Add basic automated tests around filename generation, history persistence, and upload response decoding
- [x] Add a post-upload action picker: copy link, open link, reveal local file, or do nothing
- [x] Add copy formats beyond URL, such as Markdown image link and HTML image tag
- [x] Add upload progress UI for larger files
- [x] Add clipboard-only capture mode with automatic fallback when no server is configured
- [x] Move the macOS app API token from `UserDefaults` into Keychain
- [x] Add a proper hotkey recorder UI so the global shortcut is configurable
- [x] Add active-window capture in addition to area and full-screen capture
- [x] Add thumbnail previews to Recent Uploads
- [x] Add an option to reveal the local saved file in Finder after upload
- [x] Add retry and clearer recovery paths for temporary upload failures
- [x] Improve permission onboarding with a first-run help screen
- [x] Add backend tests for auth, file validation, and max-size enforcement
- [x] Add optional Open Graph share pages for Discord-style embeds
- [x] Tighten backend upload validation with file-signature checks
- [x] Disable CORS by default unless explicitly configured on the server

## Next

- [ ] Add a server endpoint for deleting uploads with token auth
- [ ] Add support for multiple server profiles in the app

## Later

- [ ] Add scroll capture for long pages
- [ ] Add short screen recording upload support
- [ ] Add OCR on captured images with a copy-recognized-text action
- [ ] Add image optimization and automatic format conversion on the server
- [ ] Add optional signed or expiring public links
- [ ] Add S3-compatible storage support for the backend
- [ ] Add optional SQLite metadata storage for uploads
- [ ] Add rate limiting backed by Redis or reverse proxy rules
- [ ] Add a minimal admin page for server health and upload visibility
- [ ] Add optional image transformations like resize and WebP conversion

## Open Source And Release Work

- [ ] Add screenshots and a short demo GIF to the README
- [ ] Add a changelog and release process doc
- [ ] Add conventional issue labels and milestone planning
- [ ] Add a small test fixture set for backend upload cases
- [ ] Add a notarized release pipeline for the macOS app
- [ ] Add installation docs for Homebrew and standalone `.dmg` distribution
- [ ] Add a contributor-friendly local dev script for booting server and app-side prerequisites
- [ ] Add architecture decision records for major future changes

## Nice Product Ideas

- [ ] Quick share destinations after upload, such as Slack paste format or Discord embed-ready markdown
- [ ] QR code popup for opening the uploaded image on another device
- [ ] Temporary private uploads with one-click reveal links
- [ ] Per-project settings profiles tied to different servers or folders
- [ ] Keyboard-only capture flow for power users
- [ ] Auto-expiring uploads managed by the server
- [ ] Native menubar stats like last upload time and server status
