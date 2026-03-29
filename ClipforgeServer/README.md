# Clipforge Server

Clipforge Server is a small self-hosted FastAPI service that accepts authenticated image uploads, stores them on local disk, and returns a public URL for the uploaded file.

## Endpoints

- `GET /health`
- `POST /upload`
- `GET /uploads/<filename>`

## Environment Variables

- `CLIPFORGE_BASE_URL`: public base URL used to build returned file URLs
- `CLIPFORGE_UPLOAD_DIR`: local upload directory
- `CLIPFORGE_API_TOKEN`: bearer token required for uploads
- `CLIPFORGE_MAX_UPLOAD_MB`: max upload size in megabytes

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

## Notes

- Uploads are stored on local disk in `uploads/`
- Files are served statically from `/uploads`
- The built-in rate limiter is an in-memory MVP implementation and is the right place to replace with Redis or a reverse-proxy limit later
- CORS is intentionally open for MVP expansion; tighten it before exposing the service broadly
