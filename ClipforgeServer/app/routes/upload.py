from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status

from ..auth import require_bearer_token
from ..config import Settings, get_settings
from ..rate_limit import SimpleRateLimiter, get_rate_limiter
from ..utils.files import (
    FileTooLargeError,
    FileValidationError,
    build_public_url,
    save_upload_file,
)

router = APIRouter()
logger = logging.getLogger("clipforge.uploads")


@router.post("/upload", status_code=status.HTTP_201_CREATED)
async def upload_image(
    request: Request,
    file: UploadFile = File(...),
    _: None = Depends(require_bearer_token),
    settings: Settings = Depends(get_settings),
    rate_limiter: SimpleRateLimiter = Depends(get_rate_limiter),
) -> dict[str, str]:
    client_ip = request.client.host if request.client else "unknown"
    rate_limiter.check(client_ip)

    try:
        filename, total_bytes = await save_upload_file(
            upload_file=file,
            destination_dir=settings.upload_dir,
            max_upload_bytes=settings.max_upload_bytes,
        )
    except FileValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except FileTooLargeError as exc:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail=str(exc)) from exc
    except OSError as exc:
        logger.exception("Could not save upload from %s", client_ip)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not save uploaded file.",
        ) from exc

    logger.info("Uploaded %s (%s bytes) from %s", filename, total_bytes, client_ip)
    return {"url": build_public_url(settings.base_url, filename)}
