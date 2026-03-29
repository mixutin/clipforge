from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routes.upload import router as upload_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s - %(message)s",
)


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Clipforge Server",
        version="0.5.0",
        docs_url="/docs",
        redoc_url=None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    app.include_router(upload_router)

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {
            "status": "ok",
            "max_upload_mb": settings.max_upload_mb,
            "storage_backend": settings.storage_backend,
            "upload_dir": str(settings.upload_dir) if settings.uses_s3_storage is False else None,
            "share_embeds_enabled": settings.enable_share_embeds,
            "public_link_mode": settings.public_link_mode,
            "image_output_mode": settings.image_output_mode,
        }

    return app


app = create_app()
