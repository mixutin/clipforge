from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Protocol

import boto3
from botocore.config import Config as BotoConfig
from botocore.exceptions import ClientError
from fastapi.responses import FileResponse, RedirectResponse, Response

from .config import Settings, get_settings
from .utils.files import FileValidationError, guess_content_type, normalize_upload_filename


class StorageBackend(Protocol):
    def save(self, *, filename: str, data: bytes, content_type: str) -> None: ...
    def delete(self, filename: str) -> str: ...
    def exists(self, filename: str) -> bool: ...
    def response_for_download(self, filename: str) -> Response: ...


class LocalStorageBackend:
    def __init__(self, root: Path) -> None:
        self.root = root

    def save(self, *, filename: str, data: bytes, content_type: str) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        destination = self.root / normalize_upload_filename(filename)
        temporary_path = destination.with_name(f".{destination.name}.part")

        try:
            temporary_path.write_bytes(data)
            temporary_path.replace(destination)
        finally:
            temporary_path.unlink(missing_ok=True)

    def delete(self, filename: str) -> str:
        safe_filename = normalize_upload_filename(filename)
        file_path = self.root / safe_filename
        if file_path.is_file() is False:
            raise FileNotFoundError(safe_filename)

        file_path.unlink()
        return safe_filename

    def exists(self, filename: str) -> bool:
        safe_filename = normalize_upload_filename(filename)
        return (self.root / safe_filename).is_file()

    def response_for_download(self, filename: str) -> Response:
        safe_filename = normalize_upload_filename(filename)
        file_path = self.root / safe_filename
        if file_path.is_file() is False:
            raise FileNotFoundError(safe_filename)

        return FileResponse(
            path=file_path,
            media_type=guess_content_type(safe_filename),
            filename=safe_filename,
        )


class S3StorageBackend:
    redirect_expiry_seconds = 600

    def __init__(
        self,
        *,
        bucket: str,
        prefix: str,
        endpoint_url: str,
        region: str,
        access_key_id: str,
        secret_access_key: str,
        force_path_style: bool,
    ) -> None:
        client_kwargs: dict[str, object] = {
            "service_name": "s3",
            "region_name": region or None,
            "endpoint_url": endpoint_url or None,
            "config": BotoConfig(s3={"addressing_style": "path" if force_path_style else "auto"}),
        }
        if access_key_id and secret_access_key:
            client_kwargs["aws_access_key_id"] = access_key_id
            client_kwargs["aws_secret_access_key"] = secret_access_key

        self.client = boto3.client(**client_kwargs)
        self.bucket = bucket
        self.prefix = prefix.strip("/")

    def save(self, *, filename: str, data: bytes, content_type: str) -> None:
        safe_filename = normalize_upload_filename(filename)
        self.client.put_object(
            Bucket=self.bucket,
            Key=self.object_key(safe_filename),
            Body=data,
            ContentType=content_type,
            CacheControl="public, max-age=31536000, immutable",
        )

    def delete(self, filename: str) -> str:
        safe_filename = normalize_upload_filename(filename)
        if self.exists(safe_filename) is False:
            raise FileNotFoundError(safe_filename)

        self.client.delete_object(
            Bucket=self.bucket,
            Key=self.object_key(safe_filename),
        )
        return safe_filename

    def exists(self, filename: str) -> bool:
        safe_filename = normalize_upload_filename(filename)
        try:
            self.client.head_object(
                Bucket=self.bucket,
                Key=self.object_key(safe_filename),
            )
            return True
        except ClientError as exc:
            if exc.response.get("Error", {}).get("Code") in {"404", "NoSuchKey", "NotFound"}:
                return False
            raise

    def response_for_download(self, filename: str) -> Response:
        safe_filename = normalize_upload_filename(filename)
        if self.exists(safe_filename) is False:
            raise FileNotFoundError(safe_filename)

        redirect_url = self.client.generate_presigned_url(
            ClientMethod="get_object",
            Params={
                "Bucket": self.bucket,
                "Key": self.object_key(safe_filename),
                "ResponseContentType": guess_content_type(safe_filename),
            },
            ExpiresIn=self.redirect_expiry_seconds,
        )
        return RedirectResponse(url=redirect_url, status_code=307)

    def object_key(self, filename: str) -> str:
        return f"{self.prefix}/{filename}" if self.prefix else filename


@lru_cache(maxsize=1)
def get_storage_backend() -> StorageBackend:
    settings = get_settings()
    if settings.uses_s3_storage:
        return S3StorageBackend(
            bucket=settings.s3_bucket,
            prefix=settings.s3_prefix,
            endpoint_url=settings.s3_endpoint_url,
            region=settings.s3_region,
            access_key_id=settings.s3_access_key_id,
            secret_access_key=settings.s3_secret_access_key,
            force_path_style=settings.s3_force_path_style,
        )

    return LocalStorageBackend(settings.upload_dir)
