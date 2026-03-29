# Security Policy

## Supported Versions

Clipforge is currently an MVP project.

The actively supported version is:

- `main`

## Reporting A Vulnerability

Please do not open a public GitHub issue for security-sensitive bugs.

Instead:

1. Open a private security advisory on GitHub if available for the repository
2. If that is not possible, contact the maintainer directly before disclosing details publicly

When reporting a vulnerability, include:

- affected component: `Clipforge` or `Clipforge Server`
- reproduction steps
- expected impact
- any proof-of-concept details

## Security Notes

- The macOS app stores the API token in the user's macOS Keychain
- The macOS app verifies GitHub-hosted update metadata using Sparkle's Ed25519 public key
- The server uses bearer-token auth and local-disk storage for MVP use
- The server validates extension, MIME type, file size, and image signature before saving uploads
- Browser CORS is disabled by default unless explicitly configured
- Public deployments should prefer HTTPS and a reverse proxy
- The macOS app still allows non-HTTPS uploads for self-hosted MVP flexibility; treat plain HTTP deployments as local-development or trusted-network only
