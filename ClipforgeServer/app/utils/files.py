from __future__ import annotations

from dataclasses import dataclass
import io
from pathlib import Path
import secrets

from fastapi import UploadFile
from PIL import Image, ImageOps, UnidentifiedImageError

from ..config import Settings

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


@dataclass(frozen=True)
class PreparedUpload:
    filename: str
    data: bytes
    content_type: str
    media_kind: str
    total_bytes: int


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

    if extension in {".jpg", ".jpeg"} and header_bytes.startswith(b"\xff\xd8\xff"):
        return

    if extension == ".webp" and header_bytes.startswith(b"RIFF") and header_bytes[8:12] == b"WEBP":
        return

    if extension == ".mp4" and _looks_like_iso_media_file(header_bytes, allowed_brands=None):
        return

    if extension == ".mov" and _looks_like_iso_media_file(header_bytes, allowed_brands={b"qt  "}):
        return

    raise FileValidationError("The uploaded file contents do not match a supported Clipforge upload format.")


def validate_upload_type(filename: str | None, content_type: str | None) -> str:
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


async def prepare_upload_file(upload_file: UploadFile, settings: Settings) -> PreparedUpload:
    original_extension = validate_upload_type(upload_file.filename, upload_file.content_type)
    original_bytes = await read_upload_bytes(upload_file, settings.max_upload_bytes)
    validate_file_signature(original_bytes[:16], original_extension)

    media_kind = detect_media_kind_for_extension(original_extension)
    if media_kind == "video":
        return PreparedUpload(
            filename=generate_storage_filename(original_extension),
            data=original_bytes,
            content_type=guess_content_type_for_extension(original_extension),
            media_kind=media_kind,
            total_bytes=len(original_bytes),
        )

    processed_extension, processed_content_type, processed_bytes = optimize_image_bytes(
        original_bytes=original_bytes,
        original_extension=original_extension,
        settings=settings,
    )
    return PreparedUpload(
        filename=generate_storage_filename(processed_extension),
        data=processed_bytes,
        content_type=processed_content_type,
        media_kind="image",
        total_bytes=len(processed_bytes),
    )


async def read_upload_bytes(upload_file: UploadFile, max_upload_bytes: int) -> bytes:
    total_bytes = 0
    buffer = bytearray()

    try:
        while chunk := await upload_file.read(CHUNK_SIZE):
            total_bytes += len(chunk)
            if total_bytes > max_upload_bytes:
                raise FileTooLargeError(
                    f"Upload exceeds the {max_upload_bytes // (1024 * 1024)} MB limit."
                )
            buffer.extend(chunk)
    finally:
        await upload_file.close()

    if total_bytes == 0:
        raise FileValidationError("Empty uploads are not allowed.")

    return bytes(buffer)


def optimize_image_bytes(
    *,
    original_bytes: bytes,
    original_extension: str,
    settings: Settings,
) -> tuple[str, str, bytes]:
    try:
        with Image.open(io.BytesIO(original_bytes)) as opened_image:
            image = ImageOps.exif_transpose(opened_image)
            image.load()
    except (UnidentifiedImageError, OSError) as exc:
        raise FileValidationError("The uploaded file contents do not match a supported Clipforge upload format.") from exc

    if settings.image_max_dimension > 0:
        image.thumbnail((settings.image_max_dimension, settings.image_max_dimension), Image.Resampling.LANCZOS)

    output_mode = settings.image_output_mode
    if output_mode == "webp":
        return (
            ".webp",
            "image/webp",
            save_image_bytes(
                image=image,
                format_name="WEBP",
                quality=settings.image_webp_quality,
                optimize=True,
            ),
        )

    if output_mode == "optimized":
        if image_has_alpha(image):
            return (
                ".png",
                "image/png",
                save_image_bytes(image=image, format_name="PNG", optimize=True),
            )

        return (
            ".jpg",
            "image/jpeg",
            save_image_bytes(
                image=flatten_image_if_needed(image),
                format_name="JPEG",
                quality=settings.image_jpeg_quality,
                optimize=True,
                progressive=True,
            ),
        )

    return encode_original_image(
        image=image,
        original_extension=original_extension,
        settings=settings,
    )


def encode_original_image(
    *,
    image: Image.Image,
    original_extension: str,
    settings: Settings,
) -> tuple[str, str, bytes]:
    normalized_extension = ".jpg" if original_extension == ".jpeg" else original_extension
    if normalized_extension == ".png":
        return (
            ".png",
            "image/png",
            save_image_bytes(image=image, format_name="PNG", optimize=True),
        )

    if normalized_extension == ".webp":
        return (
            ".webp",
            "image/webp",
            save_image_bytes(
                image=image,
                format_name="WEBP",
                quality=settings.image_webp_quality,
                optimize=True,
            ),
        )

    return (
        ".jpg",
        "image/jpeg",
        save_image_bytes(
            image=flatten_image_if_needed(image),
            format_name="JPEG",
            quality=settings.image_jpeg_quality,
            optimize=True,
            progressive=True,
        ),
    )


def save_image_bytes(
    *,
    image: Image.Image,
    format_name: str,
    quality: int | None = None,
    optimize: bool = False,
    progressive: bool = False,
) -> bytes:
    output = io.BytesIO()
    save_kwargs: dict[str, object] = {
        "format": format_name,
        "optimize": optimize,
    }
    if quality is not None:
        save_kwargs["quality"] = quality
    if progressive:
        save_kwargs["progressive"] = True

    image.save(output, **save_kwargs)
    return output.getvalue()


def flatten_image_if_needed(image: Image.Image) -> Image.Image:
    if image_has_alpha(image) is False:
        return image.convert("RGB")

    background = Image.new("RGBA", image.size, (255, 255, 255, 255))
    background.alpha_composite(image.convert("RGBA"))
    return background.convert("RGB")


def image_has_alpha(image: Image.Image) -> bool:
    if image.mode in {"RGBA", "LA"}:
        return True

    transparency = image.info.get("transparency")
    return transparency is not None


def generate_storage_filename(extension: str) -> str:
    return f"{secrets.token_hex(16)}{extension}"


def detect_media_kind(filename: str) -> str:
    extension = Path(filename).suffix.lower()
    return detect_media_kind_for_extension(extension)


def detect_media_kind_for_extension(extension: str) -> str:
    if extension in VIDEO_EXTENSIONS:
        return "video"
    return "image"


def guess_content_type(filename: str) -> str:
    return guess_content_type_for_extension(Path(filename).suffix.lower())


def guess_content_type_for_extension(extension: str) -> str:
    if extension == ".png":
        return "image/png"
    if extension in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if extension == ".webp":
        return "image/webp"
    if extension == ".mov":
        return "video/quicktime"
    return "video/mp4"


def _looks_like_iso_media_file(header_bytes: bytes, allowed_brands: set[bytes] | None) -> bool:
    if len(header_bytes) < 12 or header_bytes[4:8] != b"ftyp":
        return False

    brand = header_bytes[8:12]
    if allowed_brands is None:
        return brand != b"qt  "

    return brand in allowed_brands
