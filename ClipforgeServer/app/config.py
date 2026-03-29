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


def _optional_env(name: str) -> str:
    return os.getenv(name, "").strip()


def _positive_int(name: str, default: int) -> int:
    raw_value = os.getenv(name, str(default)).strip()
    try:
        parsed = int(raw_value)
    except ValueError as exc:
        raise RuntimeError(f"{name} must be an integer.") from exc

    if parsed <= 0:
        raise RuntimeError(f"{name} must be greater than zero.")

    return parsed


def _non_negative_int(name: str, default: int) -> int:
    raw_value = os.getenv(name, str(default)).strip()
    try:
        parsed = int(raw_value)
    except ValueError as exc:
        raise RuntimeError(f"{name} must be an integer.") from exc

    if parsed < 0:
        raise RuntimeError(f"{name} must be zero or greater.")

    return parsed


def _bounded_int(name: str, default: int, *, minimum: int, maximum: int) -> int:
    parsed = _positive_int(name, default)
    if parsed < minimum or parsed > maximum:
        raise RuntimeError(f"{name} must be between {minimum} and {maximum}.")
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


def _enum_env(name: str, allowed: set[str], default: str) -> str:
    value = os.getenv(name, default).strip().lower()
    if value not in allowed:
        allowed_values = ", ".join(sorted(allowed))
        raise RuntimeError(f"{name} must be one of: {allowed_values}.")
    return value


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
    upload_rate_limit_per_minute: int
    public_link_mode: str
    signing_secret: str
    link_expiry_seconds: int
    image_output_mode: str
    image_max_dimension: int
    image_jpeg_quality: int
    image_webp_quality: int
    storage_backend: str
    s3_bucket: str
    s3_region: str
    s3_endpoint_url: str
    s3_access_key_id: str
    s3_secret_access_key: str
    s3_prefix: str
    s3_force_path_style: bool

    @property
    def max_upload_bytes(self) -> int:
        return self.max_upload_mb * 1024 * 1024

    @property
    def links_require_signature(self) -> bool:
        return self.public_link_mode in {"signed", "expiring"}

    @property
    def links_expire(self) -> bool:
        return self.public_link_mode == "expiring"

    @property
    def uses_s3_storage(self) -> bool:
        return self.storage_backend == "s3"


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
        upload_rate_limit_per_minute=_positive_int("CLIPFORGE_UPLOAD_RATE_LIMIT_PER_MINUTE", 60),
        public_link_mode=_enum_env("CLIPFORGE_PUBLIC_LINK_MODE", {"public", "signed", "expiring"}, "public"),
        signing_secret=_optional_env("CLIPFORGE_SIGNING_SECRET"),
        link_expiry_seconds=_positive_int("CLIPFORGE_LINK_EXPIRY_SECONDS", 86_400),
        image_output_mode=_enum_env("CLIPFORGE_IMAGE_OUTPUT_MODE", {"original", "optimized", "webp"}, "original"),
        image_max_dimension=_non_negative_int("CLIPFORGE_IMAGE_MAX_DIMENSION", 0),
        image_jpeg_quality=_bounded_int("CLIPFORGE_IMAGE_JPEG_QUALITY", 88, minimum=40, maximum=100),
        image_webp_quality=_bounded_int("CLIPFORGE_IMAGE_WEBP_QUALITY", 84, minimum=40, maximum=100),
        storage_backend=_enum_env("CLIPFORGE_STORAGE_BACKEND", {"local", "s3"}, "local"),
        s3_bucket=_optional_env("CLIPFORGE_S3_BUCKET"),
        s3_region=_optional_env("CLIPFORGE_S3_REGION"),
        s3_endpoint_url=_optional_env("CLIPFORGE_S3_ENDPOINT_URL"),
        s3_access_key_id=_optional_env("CLIPFORGE_S3_ACCESS_KEY_ID"),
        s3_secret_access_key=_optional_env("CLIPFORGE_S3_SECRET_ACCESS_KEY"),
        s3_prefix=os.getenv("CLIPFORGE_S3_PREFIX", "").strip().strip("/"),
        s3_force_path_style=_bool_env("CLIPFORGE_S3_FORCE_PATH_STYLE", False),
    )

    if settings.links_require_signature and not settings.signing_secret:
        raise RuntimeError("CLIPFORGE_SIGNING_SECRET is required when signed or expiring links are enabled.")

    if settings.uses_s3_storage and not settings.s3_bucket:
        raise RuntimeError("CLIPFORGE_S3_BUCKET is required when CLIPFORGE_STORAGE_BACKEND=s3.")

    if settings.uses_s3_storage is False:
        settings.upload_dir.mkdir(parents=True, exist_ok=True)

    return settings
