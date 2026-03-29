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

- The macOS app stores settings locally; API tokens should move to Keychain in a future release
- The server uses bearer-token auth and local-disk storage for MVP use
- Public deployments should prefer HTTPS and a reverse proxy
