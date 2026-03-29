from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is required.")
    return value


def _positive_int(name: str, default: int) -> int:
    raw_value = os.getenv(name, str(default)).strip()
    try:
        parsed = int(raw_value)
    except ValueError as exc:
        raise RuntimeError(f"{name} must be an integer.") from exc

    if parsed <= 0:
        raise RuntimeError(f"{name} must be greater than zero.")

    return parsed


def _bool_env(name: str, default: bool) -> bool:
    raw_value = os.getenv(name)
    if raw_value is None:
        return default

    normalized = raw_value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False

    raise RuntimeError(f"{name} must be a boolean.")


def _split_csv_env(name: str) -> tuple[str, ...]:
    raw_value = os.getenv(name, "").strip()
    if not raw_value:
        return ()

    return tuple(
        part.strip()
        for part in raw_value.split(",")
        if part.strip()
    )


@dataclass(frozen=True)
class Settings:
    base_url: str
    upload_dir: Path
    api_token: str
    max_upload_mb: int
    cors_allowed_origins: tuple[str, ...]
    enable_share_embeds: bool
    embed_title_template: str
    embed_description_template: str
    embed_site_name: str
    embed_theme_color: str
    upload_rate_limit_per_minute: int = 60

    @property
    def max_upload_bytes(self) -> int:
        return self.max_upload_mb * 1024 * 1024


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    settings = Settings(
        base_url=_required_env("CLIPFORGE_BASE_URL").rstrip("/"),
        upload_dir=Path(os.getenv("CLIPFORGE_UPLOAD_DIR", "uploads")).expanduser(),
        api_token=_required_env("CLIPFORGE_API_TOKEN"),
        max_upload_mb=_positive_int("CLIPFORGE_MAX_UPLOAD_MB", 10),
        cors_allowed_origins=_split_csv_env("CLIPFORGE_CORS_ALLOW_ORIGINS"),
        enable_share_embeds=_bool_env("CLIPFORGE_ENABLE_SHARE_EMBEDS", False),
        embed_title_template=os.getenv("CLIPFORGE_EMBED_TITLE_TEMPLATE", "Clipforge Upload {basename}").strip()
        or "Clipforge Upload {basename}",
        embed_description_template=os.getenv("CLIPFORGE_EMBED_DESCRIPTION_TEMPLATE", "Shared via Clipforge").strip()
        or "Shared via Clipforge",
        embed_site_name=os.getenv("CLIPFORGE_EMBED_SITE_NAME", "Clipforge").strip() or "Clipforge",
        embed_theme_color=os.getenv("CLIPFORGE_EMBED_THEME_COLOR", "#10141c").strip() or "#10141c",
    )
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    return settings
