from __future__ import annotations

from base64 import b64decode
from contextlib import contextmanager
from pathlib import Path
import sys
from urllib.parse import urlparse

import pytest
from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.config import get_settings
from app.rate_limit import get_rate_limiter
from app.storage import get_storage_backend

PNG_BYTES = b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Z0ioAAAAASUVORK5CYII="
)
MP4_BYTES = b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom\x00\x00\x00\x08free"


@contextmanager
def make_client(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    **extra_env: str,
) -> TestClient:
    upload_dir = tmp_path / "uploads"

    monkeypatch.setenv("CLIPFORGE_BASE_URL", "http://testserver")
    monkeypatch.setenv("CLIPFORGE_UPLOAD_DIR", str(upload_dir))
    monkeypatch.setenv("CLIPFORGE_API_TOKEN", "test-token")
    monkeypatch.setenv("CLIPFORGE_MAX_UPLOAD_MB", "1")
    monkeypatch.delenv("CLIPFORGE_CORS_ALLOW_ORIGINS", raising=False)
    monkeypatch.delenv("CLIPFORGE_ENABLE_SHARE_EMBEDS", raising=False)
    monkeypatch.delenv("CLIPFORGE_PUBLIC_LINK_MODE", raising=False)
    monkeypatch.delenv("CLIPFORGE_SIGNING_SECRET", raising=False)
    monkeypatch.delenv("CLIPFORGE_LINK_EXPIRY_SECONDS", raising=False)
    monkeypatch.delenv("CLIPFORGE_IMAGE_OUTPUT_MODE", raising=False)
    monkeypatch.delenv("CLIPFORGE_IMAGE_MAX_DIMENSION", raising=False)
    monkeypatch.delenv("CLIPFORGE_IMAGE_JPEG_QUALITY", raising=False)
    monkeypatch.delenv("CLIPFORGE_IMAGE_WEBP_QUALITY", raising=False)
    monkeypatch.delenv("CLIPFORGE_STORAGE_BACKEND", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_BUCKET", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_REGION", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_ENDPOINT_URL", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_ACCESS_KEY_ID", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_SECRET_ACCESS_KEY", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_PREFIX", raising=False)
    monkeypatch.delenv("CLIPFORGE_S3_FORCE_PATH_STYLE", raising=False)

    for key, value in extra_env.items():
        monkeypatch.setenv(key, value)

    get_settings.cache_clear()
    get_rate_limiter.cache_clear()
    get_storage_backend.cache_clear()

    from app.main import create_app

    app = create_app()

    with TestClient(app) as test_client:
        yield test_client

    get_settings.cache_clear()
    get_rate_limiter.cache_clear()
    get_storage_backend.cache_clear()


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> TestClient:
    with make_client(tmp_path, monkeypatch) as test_client:
        yield test_client


def test_upload_requires_bearer_token(client: TestClient) -> None:
    response = client.post(
        "/upload",
        files={"file": ("capture.png", PNG_BYTES, "image/png")},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Missing bearer token."}
    assert response.headers["www-authenticate"] == "Bearer"


def test_upload_rejects_invalid_bearer_token(client: TestClient) -> None:
    response = client.post(
        "/upload",
        headers={"Authorization": "Bearer wrong-token"},
        files={"file": ("capture.png", PNG_BYTES, "image/png")},
    )

    assert response.status_code == 401
    assert response.json() == {"detail": "Invalid API token."}
    assert response.headers["www-authenticate"] == "Bearer"


def test_upload_accepts_valid_png(client: TestClient) -> None:
    response = client.post(
        "/upload",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("capture.png", PNG_BYTES, "image/png")},
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["url"].startswith("http://testserver/uploads/")
    assert payload["direct_url"] == payload["url"]
    assert payload["share_url"].startswith("http://testserver/share/")
    assert payload["media_kind"] == "image"
    assert payload["expires_at"] is None


def test_upload_accepts_valid_mp4(client: TestClient) -> None:
    response = client.post(
        "/upload",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("capture.mp4", MP4_BYTES, "video/mp4")},
    )

    assert response.status_code == 201
    payload = response.json()
    assert payload["url"].startswith("http://testserver/uploads/")
    assert payload["direct_url"].endswith(".mp4")
    assert payload["media_kind"] == "video"


def test_upload_rejects_invalid_file_signature(client: TestClient, tmp_path: Path) -> None:
    response = client.post(
        "/upload",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("capture.png", b"not-a-real-png", "image/png")},
    )

    assert response.status_code == 400
    assert response.json() == {
        "detail": "The uploaded file contents do not match a supported Clipforge upload format."
    }
    assert list((tmp_path / "uploads").glob("*")) == []


def test_upload_rejects_oversized_files(client: TestClient, tmp_path: Path) -> None:
    oversized_png = b"\x89PNG\r\n\x1a\n" + (b"\x00" * (1024 * 1024))

    response = client.post(
        "/upload",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("capture.png", oversized_png, "image/png")},
    )

    assert response.status_code == 413
    assert response.json() == {"detail": "Upload exceeds the 1 MB limit."}
    assert list((tmp_path / "uploads").glob("*")) == []


def test_upload_returns_signed_expiring_links_when_enabled(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with make_client(
        tmp_path,
        monkeypatch,
        CLIPFORGE_PUBLIC_LINK_MODE="expiring",
        CLIPFORGE_SIGNING_SECRET="super-secret",
        CLIPFORGE_LINK_EXPIRY_SECONDS="900",
    ) as test_client:
        response = test_client.post(
            "/upload",
            headers={"Authorization": "Bearer test-token"},
            files={"file": ("capture.png", PNG_BYTES, "image/png")},
        )

        assert response.status_code == 201
        payload = response.json()
        assert "signature=" in payload["direct_url"]
        assert "expires=" in payload["direct_url"]
        assert payload["expires_at"] is not None

        unsigned_path = urlparse(payload["direct_url"]).path
        unsigned_response = test_client.get(unsigned_path)
        assert unsigned_response.status_code == 403

        signed_response = test_client.get(payload["direct_url"])
        assert signed_response.status_code == 200
        assert signed_response.headers["content-type"] == "image/png"
        assert signed_response.content.startswith(b"\x89PNG\r\n\x1a\n")


def test_upload_optimizes_images_and_can_convert_to_webp(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    with make_client(
        tmp_path,
        monkeypatch,
        CLIPFORGE_IMAGE_OUTPUT_MODE="webp",
    ) as test_client:
        response = test_client.post(
            "/upload",
            headers={"Authorization": "Bearer test-token"},
            files={"file": ("capture.png", PNG_BYTES, "image/png")},
        )

        assert response.status_code == 201
        payload = response.json()
        assert payload["direct_url"].endswith(".webp")

        saved_files = list((tmp_path / "uploads").glob("*.webp"))
        assert len(saved_files) == 1
        assert saved_files[0].read_bytes().startswith(b"RIFF")


def test_delete_requires_bearer_token(client: TestClient) -> None:
    response = client.delete("/upload/example.png")

    assert response.status_code == 401
    assert response.json() == {"detail": "Missing bearer token."}
    assert response.headers["www-authenticate"] == "Bearer"


def test_delete_rejects_invalid_filename(client: TestClient) -> None:
    response = client.delete(
        "/upload/../example.png",
        headers={"Authorization": "Bearer test-token"},
    )

    assert response.status_code == 404
    assert response.json() == {"detail": "Not Found"}


def test_delete_removes_uploaded_file(client: TestClient, tmp_path: Path) -> None:
    upload_response = client.post(
        "/upload",
        headers={"Authorization": "Bearer test-token"},
        files={"file": ("capture.png", PNG_BYTES, "image/png")},
    )
    assert upload_response.status_code == 201

    uploaded_filename = Path(urlparse(upload_response.json()["direct_url"]).path).name
    uploaded_path = tmp_path / "uploads" / uploaded_filename
    assert uploaded_path.exists()

    delete_response = client.delete(
        f"/upload/{uploaded_filename}",
        headers={"Authorization": "Bearer test-token"},
    )

    assert delete_response.status_code == 200
    assert delete_response.json() == {
        "filename": uploaded_filename,
        "status": "deleted",
    }
    assert uploaded_path.exists() is False


def test_delete_returns_not_found_for_missing_upload(client: TestClient) -> None:
    response = client.delete(
        "/upload/missing-file.png",
        headers={"Authorization": "Bearer test-token"},
    )

    assert response.status_code == 404
    assert response.json() == {"detail": "Upload not found."}
