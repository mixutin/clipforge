from __future__ import annotations

import secrets
from pathlib import Path
from urllib.parse import quote

from fastapi import UploadFile

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
VIDEO_EXTENSIONS = {".mp4", ".mov"}
ALLOWED_EXTENSIONS = IMAGE_EXTENSIONS | VIDEO_EXTENSIONS
ALLOWED_CONTENT_TYPES = {
    "image/png": {".png"},
    "image/jpeg": {".jpg", ".jpeg"},
    "image/webp": {".webp"},
    "video/mp4": {".mp4"},
    "video/quicktime": {".mov"},
}
CHUNK_SIZE = 1024 * 1024


class FileValidationError(ValueError):
    pass


class FileTooLargeError(ValueError):
    pass


def normalize_upload_filename(filename: str) -> str:
    safe_filename = Path(filename).name
    if safe_filename != filename or safe_filename in {"", ".", ".."}:
        raise FileValidationError("Invalid upload filename.")

    return safe_filename


def validate_file_signature(header_bytes: bytes, extension: str) -> None:
    if extension == ".png" and header_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return

    if extension == ".jpg" and header_bytes.startswith(b"\xff\xd8\xff"):
        return

    if extension == ".webp" and header_bytes.startswith(b"RIFF") and header_bytes[8:12] == b"WEBP":
        return

    if extension == ".mp4" and _looks_like_iso_media_file(header_bytes, allowed_brands=None):
        return

    if extension == ".mov" and _looks_like_iso_media_file(header_bytes, allowed_brands={b"qt  "}):
        return

    raise FileValidationError("The uploaded file contents do not match a supported Clipforge upload format.")


def validate_image_type(filename: str | None, content_type: str | None) -> str:
    if not content_type or content_type not in ALLOWED_CONTENT_TYPES:
        raise FileValidationError("Only PNG, JPG, JPEG, WEBP, MP4, and MOV uploads are supported.")

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
    header_bytes = bytearray()

    try:
        with temporary_path.open("wb") as file_handle:
            while chunk := await upload_file.read(CHUNK_SIZE):
                total_bytes += len(chunk)
                if total_bytes > max_upload_bytes:
                    raise FileTooLargeError(
                        f"Upload exceeds the {max_upload_bytes // (1024 * 1024)} MB limit."
                    )

                if len(header_bytes) < 16:
                    remaining = 16 - len(header_bytes)
                    header_bytes.extend(chunk[:remaining])

                file_handle.write(chunk)

        if total_bytes == 0:
            raise FileValidationError("Empty uploads are not allowed.")

        validate_file_signature(bytes(header_bytes), extension)
        temporary_path.replace(final_path)
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise
    finally:
        await upload_file.close()

    return generated_name, total_bytes


def delete_upload_file(filename: str, destination_dir: Path) -> str:
    safe_filename = normalize_upload_filename(filename)
    file_path = destination_dir / safe_filename

    if file_path.is_file() is False:
        raise FileNotFoundError(safe_filename)

    file_path.unlink()
    return safe_filename


def build_public_url(base_url: str, filename: str) -> str:
    return f"{base_url}/uploads/{quote(filename)}"


def detect_media_kind(filename: str) -> str:
    extension = Path(filename).suffix.lower()
    if extension in VIDEO_EXTENSIONS:
        return "video"
    return "image"


def _looks_like_iso_media_file(header_bytes: bytes, allowed_brands: set[bytes] | None) -> bool:
    if len(header_bytes) < 12 or header_bytes[4:8] != b"ftyp":
        return False

    brand = header_bytes[8:12]
    if allowed_brands is None:
        return brand != b"qt  "

    return brand in allowed_brands
