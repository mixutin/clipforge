from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
import hmac
import hashlib
from time import time
from urllib.parse import quote, urlencode

from fastapi import HTTPException, Request, status

from .config import Settings


@dataclass(frozen=True)
class PublicLink:
    url: str
    expires_at: str | None = None


def build_upload_url(settings: Settings, filename: str) -> PublicLink:
    path = f"/uploads/{quote(filename)}"
    return build_public_link(settings, path)


def build_share_url(settings: Settings, filename: str) -> PublicLink:
    path = f"/share/{quote(filename)}"
    return build_public_link(settings, path)


def build_public_link(settings: Settings, path: str) -> PublicLink:
    base_url = f"{settings.base_url}{path}"
    if settings.public_link_mode == "public":
        return PublicLink(url=base_url)

    expires_at_timestamp: int | None = None
    expires_at_iso: str | None = None
    if settings.links_expire:
        expires_at_timestamp = int(time()) + settings.link_expiry_seconds
        expires_at_iso = datetime.fromtimestamp(expires_at_timestamp, UTC).isoformat()

    signature = sign_path(
        path=path,
        secret=settings.signing_secret,
        expires_at=expires_at_timestamp,
    )
    params = {"signature": signature}
    if expires_at_timestamp is not None:
        params["expires"] = str(expires_at_timestamp)

    return PublicLink(
        url=f"{base_url}?{urlencode(params)}",
        expires_at=expires_at_iso,
    )


def verify_public_link_request(request: Request, settings: Settings) -> None:
    if settings.public_link_mode == "public":
        return

    signature = request.query_params.get("signature", "").strip()
    if not signature:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Signed Clipforge links require a valid signature.",
        )

    expires_value = request.query_params.get("expires", "").strip()
    expires_at: int | None = None
    if settings.links_expire:
        if not expires_value:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Expiring Clipforge links require an expiry timestamp.",
            )

        try:
            expires_at = int(expires_value)
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Invalid Clipforge link expiry.",
            ) from exc

        if expires_at < int(time()):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="This Clipforge link has expired.",
            )

    expected_signature = sign_path(
        path=request.url.path,
        secret=settings.signing_secret,
        expires_at=expires_at,
    )
    if not hmac.compare_digest(signature, expected_signature):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid Clipforge link signature.",
        )


def sign_path(path: str, secret: str, expires_at: int | None) -> str:
    payload = f"{path}\n{expires_at or ''}".encode("utf-8")
    return hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
