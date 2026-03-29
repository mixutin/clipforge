# Clipforge Server

Clipforge Server is a small self-hosted FastAPI service that accepts authenticated image and short video uploads, stores them on local disk or S3-compatible object storage, and returns a public URL for the uploaded file.

## Endpoints

- `GET /health`
- `POST /upload`
- `DELETE /upload/<filename>`
- `GET /uploads/<filename>`
- `GET /share/<filename>`

## Environment Variables

- `CLIPFORGE_BASE_URL`: public base URL used to build returned file URLs
- `CLIPFORGE_UPLOAD_DIR`: local upload directory
- `CLIPFORGE_API_TOKEN`: bearer token required for uploads
- `CLIPFORGE_MAX_UPLOAD_MB`: max upload size in megabytes
- `CLIPFORGE_CORS_ALLOW_ORIGINS`: optional comma-separated browser origins allowed for CORS
- `CLIPFORGE_ENABLE_SHARE_EMBEDS`: when `true`, uploads return a share-page URL with Open Graph metadata instead of the raw image URL
- `CLIPFORGE_EMBED_TITLE_TEMPLATE`: default embed title template. Supports `{filename}`, `{basename}`, `{direct_url}`, and `{share_url}`
- `CLIPFORGE_EMBED_DESCRIPTION_TEMPLATE`: default embed description template with the same placeholders
- `CLIPFORGE_EMBED_SITE_NAME`: default site name for Open Graph and Twitter metadata
- `CLIPFORGE_EMBED_THEME_COLOR`: optional six-digit hex color used as the share page theme color
- `CLIPFORGE_PUBLIC_LINK_MODE`: `public`, `signed`, or `expiring`
- `CLIPFORGE_SIGNING_SECRET`: required when using signed or expiring public links
- `CLIPFORGE_LINK_EXPIRY_SECONDS`: expiry window used by expiring public links
- `CLIPFORGE_IMAGE_OUTPUT_MODE`: `original`, `optimized`, or `webp`
- `CLIPFORGE_IMAGE_MAX_DIMENSION`: optional maximum width or height in pixels, `0` to disable resizing
- `CLIPFORGE_IMAGE_JPEG_QUALITY`: JPEG quality used for optimized JPEG output
- `CLIPFORGE_IMAGE_WEBP_QUALITY`: WebP quality used for converted images
- `CLIPFORGE_STORAGE_BACKEND`: `local` or `s3`
- `CLIPFORGE_S3_BUCKET`: bucket name for S3-compatible storage
- `CLIPFORGE_S3_REGION`: optional AWS region
- `CLIPFORGE_S3_ENDPOINT_URL`: optional custom endpoint for MinIO, Cloudflare R2, Backblaze B2, and other S3-compatible providers
- `CLIPFORGE_S3_ACCESS_KEY_ID`: optional explicit S3 access key
- `CLIPFORGE_S3_SECRET_ACCESS_KEY`: optional explicit S3 secret key
- `CLIPFORGE_S3_PREFIX`: optional object key prefix inside the bucket
- `CLIPFORGE_S3_FORCE_PATH_STYLE`: set `true` for providers that require path-style bucket URLs
- `CLIPFORGE_UPLOAD_RATE_LIMIT_PER_MINUTE`: in-memory request limit per client IP

## Run Locally

1. Create a virtual environment and install dependencies:

   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   ```

2. Copy the environment example and update it:

   ```bash
   cp .env.example .env
   ```

3. Start the server:

   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 --env-file .env
   ```

4. Verify the health check:

   ```bash
   curl http://127.0.0.1:8000/health
   ```

5. Run the backend tests:

   ```bash
   pytest -q
   ```

## Notes

- Uploads can be stored on local disk in `uploads/` or in an S3-compatible bucket
- Local disk and S3-compatible storage both use the same `/uploads/<filename>` and `/share/<filename>` public URLs
- Supported upload formats are `png`, `jpg`, `jpeg`, `webp`, `mp4`, and `mov`
- Uploads can be deleted again through `DELETE /upload/<filename>` with the same bearer token auth
- Files are served through Clipforge so optional signed/expiring links work for both local and S3-backed deployments
- Optional share pages are served from `/share/<filename>` and are useful for Discord-style rich embeds for both images and videos
- Image uploads can optionally be resized, optimized, or converted to WebP before storage
- CORS is disabled by default unless `CLIPFORGE_CORS_ALLOW_ORIGINS` is set
- The built-in rate limiter is an in-memory MVP implementation and is the right place to replace with Redis or a reverse-proxy limit later
