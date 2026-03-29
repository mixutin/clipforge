from __future__ import annotations

import secrets
from pathlib import Path
from urllib.parse import quote

from fastapi import UploadFile

ALLOWED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
ALLOWED_CONTENT_TYPES = {
    "image/png": {".png"},
    "image/jpeg": {".jpg", ".jpeg"},
    "image/webp": {".webp"},
}
CHUNK_SIZE = 1024 * 1024


class FileValidationError(ValueError):
    pass


class FileTooLargeError(ValueError):
    pass


def validate_image_type(filename: str | None, content_type: str | None) -> str:
    if not content_type or content_type not in ALLOWED_CONTENT_TYPES:
        raise FileValidationError("Only PNG, JPG, JPEG, and WEBP uploads are supported.")

    extension = Path(filename or "").suffix.lower()
    if not extension:
        return ".jpg" if content_type == "image/jpeg" else next(iter(ALLOWED_CONTENT_TYPES[content_type]))

    if extension not in ALLOWED_EXTENSIONS:
        raise FileValidationError("The uploaded file extension is not supported.")

    if extension not in ALLOWED_CONTENT_TYPES[content_type]:
        raise FileValidationError("The uploaded file extension does not match the content type.")

    return ".jpg" if extension == ".jpeg" else extension


async def save_upload_file(
    upload_file: UploadFile,
    destination_dir: Path,
    max_upload_bytes: int,
) -> tuple[str, int]:
    extension = validate_image_type(upload_file.filename, upload_file.content_type)
    generated_name = f"{secrets.token_hex(16)}{extension}"
    temporary_path = destination_dir / f".{generated_name}.part"
    final_path = destination_dir / generated_name

    total_bytes = 0

    try:
        with temporary_path.open("wb") as file_handle:
            while chunk := await upload_file.read(CHUNK_SIZE):
                total_bytes += len(chunk)
                if total_bytes > max_upload_bytes:
                    raise FileTooLargeError(
                        f"Upload exceeds the {max_upload_bytes // (1024 * 1024)} MB limit."
                    )

                file_handle.write(chunk)

        if total_bytes == 0:
            raise FileValidationError("Empty uploads are not allowed.")

        temporary_path.replace(final_path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise
    finally:
        await upload_file.close()

    return generated_name, total_bytes


def build_public_url(base_url: str, filename: str) -> str:
    return f"{base_url}/uploads/{quote(filename)}"
