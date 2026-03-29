from __future__ import annotations

from collections import defaultdict, deque
from functools import lru_cache
from threading import Lock
from time import monotonic

from fastapi import HTTPException, status

from .config import get_settings


class SimpleRateLimiter:
    def __init__(self, max_requests: int, window_seconds: int = 60) -> None:
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._lock = Lock()
        self._buckets: dict[str, deque[float]] = defaultdict(deque)

    def check(self, key: str) -> None:
        now = monotonic()

        with self._lock:
            bucket = self._buckets[key]

            while bucket and now - bucket[0] >= self.window_seconds:
                bucket.popleft()

            if len(bucket) >= self.max_requests:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many uploads. Slow down and try again in a moment.",
                )

            bucket.append(now)


@lru_cache(maxsize=1)
def get_rate_limiter() -> SimpleRateLimiter:
    settings = get_settings()
    return SimpleRateLimiter(
        max_requests=settings.upload_rate_limit_per_minute,
        window_seconds=60,
    )
