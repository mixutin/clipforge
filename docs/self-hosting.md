# Self-Hosting Guide

Clipforge Server is designed to be easy to run on a small VPS, homelab box, or local machine.

## Minimum Setup

1. Create a Python virtual environment
2. Install the requirements
3. Set environment variables from `.env.example`
4. Run the app with Uvicorn
5. Point the macOS app at the server URL and token

## Recommended Production Setup

- run the app behind Nginx, Caddy, or another reverse proxy
- terminate TLS at the proxy
- expose only HTTPS publicly
- keep uploads on durable storage
- enable signed or expiring public links if you do not want permanent anonymous URLs
- rotate the API token if it is leaked

## Example Reverse Proxy Notes

For internet-facing deployments, the proxy should:

- serve `https://your-domain`
- forward `POST /upload`
- forward `GET /health`
- forward `GET /uploads/*`
- forward `GET /share/*`

## Operational Notes

- the current rate limiter is in-memory and per-process
- storage can be local disk or an S3-compatible bucket
- image uploads can optionally be resized, optimized, or converted to WebP before they are stored
- public links can be open, signed, or signed with expiry timestamps
- the API is intentionally small and stable for MVP use
