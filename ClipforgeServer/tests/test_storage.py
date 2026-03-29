from __future__ import annotations

from pathlib import Path
import sys

from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.storage import S3StorageBackend


class FakeS3Client:
    def __init__(self) -> None:
        self.saved: dict[str, bytes] = {}

    def put_object(self, *, Bucket: str, Key: str, Body: bytes, ContentType: str, CacheControl: str) -> None:
        self.saved[Key] = Body

    def head_object(self, *, Bucket: str, Key: str) -> None:
        if Key not in self.saved:
            raise ClientError({"Error": {"Code": "404"}}, "HeadObject")

    def delete_object(self, *, Bucket: str, Key: str) -> None:
        self.saved.pop(Key, None)

    def generate_presigned_url(self, ClientMethod: str, Params: dict[str, str], ExpiresIn: int) -> str:
        return f"https://example-s3.invalid/{Params['Key']}?expires={ExpiresIn}"


def test_s3_backend_uses_prefix_and_presigned_download_redirect() -> None:
    backend = S3StorageBackend(
        bucket="clipforge",
        prefix="uploads/screens",
        endpoint_url="https://s3.example.com",
        region="eu-north-1",
        access_key_id="access",
        secret_access_key="secret",
        force_path_style=True,
    )
    backend.client = FakeS3Client()

    backend.save(filename="capture.png", data=b"png-bytes", content_type="image/png")

    assert backend.exists("capture.png") is True
    assert backend.client.saved == {"uploads/screens/capture.png": b"png-bytes"}

    response = backend.response_for_download("capture.png")
    assert response.status_code == 307
    assert response.headers["location"] == "https://example-s3.invalid/uploads/screens/capture.png?expires=600"

    deleted_filename = backend.delete("capture.png")
    assert deleted_filename == "capture.png"
    assert backend.exists("capture.png") is False
