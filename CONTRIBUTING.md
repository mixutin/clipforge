# Contributing

Thanks for your interest in improving Clipforge.

## Ground Rules

- Keep the product fast, minimal, and native-feeling
- Prefer small, focused pull requests
- Preserve self-hosting simplicity
- Avoid adding dependencies unless they clearly pay for themselves

## Development Setup

### macOS App

```bash
cd Clipforge
xcodegen generate
open Clipforge.xcodeproj
```

### Backend

```bash
cd ClipforgeServer
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --env-file .env
```

## Pull Requests

- Describe the user-facing change clearly
- Mention any permission, security, or deployment impact
- Keep documentation updated when behavior changes
- Include validation notes for macOS build and backend checks

## Style Notes

- Swift code should stay modular and production-minded
- Use SwiftUI where it makes sense, AppKit where macOS-native behavior requires it
- FastAPI code should stay lightweight, explicit, and easy to self-host

## Reporting Bugs

Please use the GitHub issue templates so reports include the details needed to reproduce problems quickly.
