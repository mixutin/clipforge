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


@dataclass(frozen=True)
class Settings:
    base_url: str
    upload_dir: Path
    api_token: str
    max_upload_mb: int
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
    )
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    return settings
