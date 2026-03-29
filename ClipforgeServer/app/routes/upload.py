from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import HTMLResponse, RedirectResponse, Response

from ..auth import require_bearer_token
from ..config import Settings, get_settings
from ..public_links import build_share_url, build_upload_url, verify_public_link_request
from ..rate_limit import SimpleRateLimiter, get_rate_limiter
from ..storage import StorageBackend, get_storage_backend
from ..utils.files import (
    FileTooLargeError,
    FileValidationError,
    detect_media_kind,
    normalize_upload_filename,
    prepare_upload_file,
)
from ..utils.share import (
    ShareMetadata,
    build_share_page_html,
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
    storage: StorageBackend = Depends(get_storage_backend),
) -> dict[str, str | None]:
    client_ip = request.client.host if request.client else "unknown"
    rate_limiter.check(client_ip)

    try:
        prepared_upload = await prepare_upload_file(
            upload_file=file,
            settings=settings,
        )
        storage.save(
            filename=prepared_upload.filename,
            data=prepared_upload.data,
            content_type=prepared_upload.content_type,
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

    direct_link = build_upload_url(settings, prepared_upload.filename)
    share_link = build_share_url(settings, prepared_upload.filename)
    returned_url = (
        share_link.url
        if settings.enable_share_embeds
        else direct_link.url
    )

    logger.info(
        "Uploaded %s (%s bytes) from %s via %s storage",
        prepared_upload.filename,
        prepared_upload.total_bytes,
        client_ip,
        settings.storage_backend,
    )
    return {
        "url": returned_url,
        "direct_url": direct_link.url,
        "share_url": share_link.url,
        "media_kind": prepared_upload.media_kind,
        "expires_at": direct_link.expires_at if settings.enable_share_embeds is False else share_link.expires_at,
    }


@router.api_route("/uploads/{filename}", methods=["GET", "HEAD"], response_model=None)
async def serve_upload(
    filename: str,
    request: Request,
    settings: Settings = Depends(get_settings),
    storage: StorageBackend = Depends(get_storage_backend),
) -> Response:
    try:
        safe_filename = normalize_upload_filename(filename)
    except FileValidationError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.") from exc

    verify_public_link_request(request, settings)

    try:
        return storage.response_for_download(safe_filename)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.") from exc
    except OSError as exc:
        logger.exception("Could not serve upload %s", safe_filename)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not open uploaded file.",
        ) from exc


@router.delete("/upload/{filename}")
async def delete_image(
    filename: str,
    request: Request,
    _: None = Depends(require_bearer_token),
    settings: Settings = Depends(get_settings),
    storage: StorageBackend = Depends(get_storage_backend),
) -> dict[str, str]:
    client_ip = request.client.host if request.client else "unknown"

    try:
        deleted_filename = storage.delete(filename)
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
    request: Request,
    settings: Settings = Depends(get_settings),
    storage: StorageBackend = Depends(get_storage_backend),
) -> Response:
    try:
        safe_filename = normalize_upload_filename(filename)
    except FileValidationError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.") from exc

    verify_public_link_request(request, settings)

    if storage.exists(safe_filename) is False:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Upload not found.")

    direct_link = build_upload_url(settings, safe_filename)
    share_link = build_share_url(settings, safe_filename)
    media_kind = detect_media_kind(safe_filename)

    if settings.enable_share_embeds is False:
        return RedirectResponse(url=direct_link.url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)

    context = make_share_context(
        filename=safe_filename,
        direct_url=direct_link.url,
        share_url=share_link.url,
    )
    title = render_share_template(settings.embed_title_template, context) or "Clipforge Upload"
    description = render_share_template(settings.embed_description_template, context) or "Shared via Clipforge"
    site_name = render_share_template(settings.embed_site_name, context) or "Clipforge"

    metadata = ShareMetadata(
        title=title,
        description=description,
        site_name=site_name,
        direct_url=direct_link.url,
        share_url=share_link.url,
        media_kind=media_kind,
        theme_color=normalize_theme_color(settings.embed_theme_color),
    )
    return HTMLResponse(content=build_share_page_html(metadata))
