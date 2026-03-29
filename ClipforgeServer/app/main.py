from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

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
        version="0.3.0",
        docs_url="/docs",
        redoc_url=None,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_allowed_origins),
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["*"],
    )

    app.include_router(upload_router)
    app.mount("/uploads", StaticFiles(directory=str(settings.upload_dir)), name="uploads")

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {
            "status": "ok",
            "max_upload_mb": settings.max_upload_mb,
            "upload_dir": str(settings.upload_dir),
            "share_embeds_enabled": settings.enable_share_embeds,
        }

    return app


app = create_app()
