from __future__ import annotations

import logging
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import HTMLResponse, RedirectResponse, Response

from ..auth import require_bearer_token
from ..config import Settings, get_settings
from ..rate_limit import SimpleRateLimiter, get_rate_limiter
from ..utils.files import (
    FileTooLargeError,
    FileValidationError,
    build_public_url,
    delete_upload_file,
    normalize_upload_filename,
    save_upload_file,
)
from ..utils.share import (
    ShareMetadata,
    build_share_page_html,
    build_share_url,
    make_share_context,
    normalize_theme_color,
    render_share_template,
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
        raise HTTPException(status_code=status.HTTP_413_CONTENT_TOO_LARGE, detail=str(exc)) from exc
    except OSError as exc:
        logger.exception("Could not save upload from %s", client_ip)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not save uploaded file.",
        ) from exc

    direct_url = build_public_url(settings.base_url, filename)
    returned_url = build_share_url(settings.base_url, filename) if settings.enable_share_embeds else direct_url

    logger.info("Uploaded %s (%s bytes) from %s", filename, total_bytes, client_ip)
    return {
        "url": returned_url,
        "direct_url": direct_url,
        "share_url": build_share_url(settings.base_url, filename),
    }


@router.delete("/upload/{filename}")
async def delete_image(
    filename: str,
    request: Request,
    _: None = Depends(require_bearer_token),
    settings: Settings = Depends(get_settings),
) -> dict[str, str]:
    client_ip = request.client.host if request.client else "unknown"

    try:
        deleted_filename = delete_upload_file(filename, settings.upload_dir)
    except FileValidationError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.") from exc
    except OSError as exc:
        logger.exception("Could not delete upload %s from %s", filename, client_ip)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not delete uploaded file.",
        ) from exc

    logger.info("Deleted %s from %s", deleted_filename, client_ip)
    return {"filename": deleted_filename, "status": "deleted"}


@router.get("/share/{filename}", response_class=HTMLResponse, response_model=None)
async def share_image(
    filename: str,
    settings: Settings = Depends(get_settings),
) -> Response:
    try:
        safe_filename = normalize_upload_filename(filename)
    except FileValidationError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.") from exc

    file_path = settings.upload_dir / safe_filename
    if file_path.is_file() is False:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.")

    direct_url = build_public_url(settings.base_url, safe_filename)
    share_url = build_share_url(settings.base_url, safe_filename)

    if settings.enable_share_embeds is False:
        return RedirectResponse(url=direct_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

    context = make_share_context(
        filename=safe_filename,
        direct_url=direct_url,
        share_url=share_url,
    )
    title = render_share_template(settings.embed_title_template, context) or "Clipforge Upload"
    description = render_share_template(settings.embed_description_template, context) or "Shared via Clipforge"
    site_name = render_share_template(settings.embed_site_name, context) or "Clipforge"

    metadata = ShareMetadata(
        title=title,
        description=description,
        site_name=site_name,
        direct_url=direct_url,
        share_url=share_url,
        theme_color=normalize_theme_color(settings.embed_theme_color),
    )
    return HTMLResponse(content=build_share_page_html(metadata))
