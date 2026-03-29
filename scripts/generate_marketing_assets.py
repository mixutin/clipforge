#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "docs" / "assets"
WIDTH = 1440
HEIGHT = 960

BG_TOP = (11, 18, 31)
BG_BOTTOM = (35, 55, 84)
CARD = (18, 25, 37)
CARD_ALT = (25, 34, 49)
CARD_BORDER = (76, 92, 119)
CARD_BORDER_SOFT = (60, 74, 96)
TEXT = (244, 247, 251)
TEXT_MUTED = (171, 182, 199)
TEXT_DIM = (137, 150, 171)
ACCENT = (93, 169, 255)
GREEN = (46, 114, 93)
BLUE = (37, 60, 105)
GRAY_BUTTON = (77, 89, 110)
URL = (121, 170, 240)
THUMB_BG = (45, 57, 77)
SUCCESS = (38, 96, 78)
WARNING = (205, 151, 64)


def load_font(size: int, bold: bool = False, italic: bool = False) -> ImageFont.FreeTypeFont:
    candidates: list[tuple[str, int]] = []
    if bold and italic:
        candidates.extend(
            [
                ("/System/Library/Fonts/Avenir Next.ttc", 3),
                ("/System/Library/Fonts/HelveticaNeue.ttc", 3),
            ]
        )
    elif bold:
        candidates.extend(
            [
                ("/System/Library/Fonts/Avenir Next.ttc", 1),
                ("/System/Library/Fonts/HelveticaNeue.ttc", 1),
            ]
        )
    elif italic:
        candidates.extend(
            [
                ("/System/Library/Fonts/Avenir Next.ttc", 2),
                ("/System/Library/Fonts/HelveticaNeue.ttc", 2),
            ]
        )
    else:
        candidates.extend(
            [
                ("/System/Library/Fonts/Avenir Next.ttc", 0),
                ("/System/Library/Fonts/HelveticaNeue.ttc", 0),
                ("/System/Library/Fonts/Helvetica.ttc", 0),
            ]
        )

    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except OSError:
            continue

    return ImageFont.load_default()


TITLE_FONT = load_font(58, bold=True, italic=True)
SUBTITLE_FONT = load_font(26, bold=True)
CARD_TITLE_FONT = load_font(30, bold=True, italic=True)
BODY_FONT = load_font(23, bold=True)
SMALL_FONT = load_font(19, bold=True)
MONO_FONT = load_font(18)
ACTION_FONT = load_font(21, bold=True)
MICRO_FONT = load_font(17, bold=True)


def canvas() -> Image.Image:
    image = Image.new("RGB", (WIDTH, HEIGHT), BG_TOP)
    pixels = image.load()

    for y in range(HEIGHT):
        t = y / max(HEIGHT - 1, 1)
        r = int(BG_TOP[0] * (1 - t) + BG_BOTTOM[0] * t)
        g = int(BG_TOP[1] * (1 - t) + BG_BOTTOM[1] * t)
        b = int(BG_TOP[2] * (1 - t) + BG_BOTTOM[2] * t)
        for x in range(WIDTH):
            pixels[x, y] = (r, g, b)

    image = image.convert("RGBA")
    for box, color, blur, alpha in [
        ((-80, -120, 740, 520), (70, 128, 210), 95, 110),
        ((300, -140, 1300, 540), (14, 42, 87), 110, 130),
        ((-30, 280, 860, 940), (39, 74, 128), 120, 75),
    ]:
        mask = Image.new("L", (WIDTH, HEIGHT), 0)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.ellipse(box, fill=alpha)
        overlay = Image.new("RGBA", (WIDTH, HEIGHT), color + (0,))
        overlay.putalpha(mask.filter(ImageFilter.GaussianBlur(blur)))
        image = Image.alpha_composite(image, overlay)

    return image.convert("RGB")


def draw_panel(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill=CARD, outline=CARD_BORDER, radius: int = 26, width: int = 2) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> int:
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def fit_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> str:
    if text_width(draw, text, font) <= max_width:
        return text

    ellipsis = "..."
    trimmed = text
    while trimmed:
        trimmed = trimmed[:-1]
        candidate = trimmed.rstrip() + ellipsis
        if text_width(draw, candidate, font) <= max_width:
            return candidate

    return ellipsis


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_width: int) -> list[str]:
    words = text.split()
    if not words:
        return [""]

    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        candidate = f"{current} {word}"
        if text_width(draw, candidate, font) <= max_width:
            current = candidate
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def draw_button(draw: ImageDraw.ImageDraw, x: int, y: int, width: int, label: str, fill: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((x, y, x + width, y + 34), radius=17, fill=fill)
    bbox = draw.textbbox((0, 0), label, font=SMALL_FONT)
    label_x = x + (width - (bbox[2] - bbox[0])) / 2
    label_y = y + (34 - (bbox[3] - bbox[1])) / 2 - 1
    draw.text((label_x, label_y), label, font=SMALL_FONT, fill=TEXT)


def draw_header(draw: ImageDraw.ImageDraw, title: str, subtitle: str) -> None:
    draw.text((88, 70), title, font=TITLE_FONT, fill=TEXT)
    draw.text((90, 148), subtitle, font=SUBTITLE_FONT, fill=TEXT_MUTED)


def draw_thumb(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: tuple[int, int, int], is_video: bool = False) -> None:
    draw.rounded_rectangle(box, radius=18, fill=THUMB_BG)

    stripe_height = 8
    gap = 6
    y = box[1] + 12
    for index in range(5):
        strength = 0.56 + (index * 0.08)
        stripe_color = tuple(min(255, int(channel * strength)) for channel in color)
        draw.rounded_rectangle((box[0] + 12, y, box[2] - 12, y + stripe_height), radius=4, fill=stripe_color)
        y += stripe_height + gap

    if is_video:
        cx = (box[0] + box[2]) // 2
        cy = (box[1] + box[3]) // 2
        draw.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(248, 250, 252))
        draw.polygon([(cx - 4, cy - 9), (cx - 4, cy + 9), (cx + 10, cy)], fill=(36, 50, 74))


def write_recent_uploads(draw: ImageDraw.ImageDraw) -> None:
    card = (82, 344, 842, 830)
    draw_panel(draw, card, radius=34)
    draw.text((116, 382), "Recent Uploads", font=CARD_TITLE_FONT, fill=TEXT)
    draw.text((116, 420), "Images and screen clips stay searchable outside the menu bar too.", font=SMALL_FONT, fill=TEXT_MUTED)

    rows = [
        ("scroll-capture-2026-03-29.png", "Markdown copied · OCR ready", ACCENT, False),
        ("clip-2026-03-29-0840.mp4", "8s screen clip · uploaded", (94, 214, 178), True),
        ("window-shot-design-review.jpg", "Finder revealed after upload", (243, 174, 68), False),
    ]

    top = 472
    for name, detail, color, is_video in rows:
        box = (116, top, 808, top + 104)
        draw_panel(draw, box, fill=CARD_ALT, outline=CARD_BORDER_SOFT, radius=24)
        draw_thumb(draw, (138, top + 18, 246, top + 86), color, is_video=is_video)
        draw.text((272, top + 24), fit_text(draw, name, BODY_FONT, 360), font=BODY_FONT, fill=TEXT)
        draw.text((272, top + 58), fit_text(draw, detail, SMALL_FONT, 360), font=SMALL_FONT, fill=TEXT_MUTED)
        draw_button(draw, 652, top + 34, 66, "Copy", BLUE)
        draw_button(draw, 728, top + 34, 62, "Open", GREEN)
        top += 118


def draw_popover(draw: ImageDraw.ImageDraw) -> None:
    bar = (82, 230, 1220, 282)
    draw_panel(draw, bar, fill=(13, 18, 28), outline=(46, 58, 77), radius=18)
    draw.text((110, 244), "08:41", font=BODY_FONT, fill=TEXT)
    draw.text((1060, 244), "Clipforge", font=BODY_FONT, fill=TEXT)

    popover = (938, 180, 1330, 786)
    draw_panel(draw, popover, radius=34)
    draw.text((992, 220), "Capture", font=CARD_TITLE_FONT, fill=TEXT)
    draw.text((992, 258), "Primary profile · clips.example", font=SMALL_FONT, fill=TEXT_MUTED)

    actions = [
        ("Capture Area", "Global hotkey ready"),
        ("Capture Full Screen", "Display under cursor"),
        ("Capture Active Window", "Frontmost app window"),
        ("Scroll Capture", "Guided long-page stitch"),
        ("Record 8s Screen Clip", "Uploads MP4 clips"),
        ("Paste Clipboard Image", "Command-V"),
    ]

    top = 300
    for label, detail in actions:
        box = (966, top, 1306, top + 62)
        highlight = label == "Scroll Capture"
        draw_panel(
            draw,
            box,
            fill=(30, 45, 66) if highlight else CARD_ALT,
            outline=ACCENT if highlight else CARD_BORDER_SOFT,
            radius=20,
        )
        draw.text((988, top + 13), fit_text(draw, label, ACTION_FONT, 290), font=ACTION_FONT, fill=TEXT)
        draw.text((988, top + 39), fit_text(draw, detail, MICRO_FONT, 290), font=MICRO_FONT, fill=TEXT_MUTED)
        top += 74

    footer = "OCR copy, drag-and-drop uploads, and video clips stay fast."
    lines = wrap_text(draw, footer, MICRO_FONT, 330)
    draw.multiline_text((968, 734), "\n".join(lines[:2]), font=MICRO_FONT, fill=TEXT_DIM, spacing=5)


def draw_success_toast(draw: ImageDraw.ImageDraw) -> None:
    box = (406, 782, 992, 884)
    draw_panel(draw, box, fill=(15, 21, 31), outline=(73, 89, 112), radius=24)
    draw.text((434, 806), "Uploaded successfully", font=BODY_FONT, fill=TEXT)
    draw.text((434, 842), "Markdown copied, OCR ready, and the local file is safe.", font=SMALL_FONT, fill=TEXT_MUTED)
    draw_button(draw, 812, 810, 148, "Copy Text", SUCCESS)


def generate_menu_popover_png() -> None:
    image = canvas()
    draw = ImageDraw.Draw(image)
    draw_header(draw, "Clipforge", "Fast native capture, upload, OCR, and screen clip sharing.")
    write_recent_uploads(draw)
    draw_popover(draw)
    draw_success_toast(draw)
    image.save(OUT_DIR / "clipforge-menu-popover.png")


def generate_history_png() -> None:
    image = canvas()
    draw = ImageDraw.Draw(image)
    draw_header(draw, "Searchable History", "Compact in the menu bar, roomy when you need to filter, copy, and reopen old shares.")

    window = (118, 220, 1324, 852)
    draw_panel(draw, window, radius=36)
    draw.text((160, 262), "Upload History", font=CARD_TITLE_FONT, fill=TEXT)
    draw.text((160, 306), "Search filenames, URLs, OCR text, and revisit uploads across server profiles.", font=SMALL_FONT, fill=TEXT_MUTED)

    search = (160, 346, 1282, 404)
    draw_panel(draw, search, fill=CARD_ALT, outline=CARD_BORDER_SOFT, radius=20)
    draw.text((188, 362), "Search uploads, OCR text, or copied URLs...", font=BODY_FONT, fill=TEXT_DIM)

    rows = [
        ("scroll-capture-2026-03-29.png", 'ocr: "Revenue grew 21% YoY"', "https://clips.example/share/scroll-capture-2026-03-29", ACCENT, False, True),
        ("clip-2026-03-29-0840.mp4", "screen clip · 8 seconds", "https://clips.example/uploads/clip-2026-03-29-0840.mp4", (94, 214, 178), True, False),
        ("paste-clipboard-sketch.png", "markdown copied · clipboard source", "https://clips.example/share/paste-clipboard-sketch", (135, 197, 214), False, True),
        ("window-shot-design-review.jpg", "revealed in Finder after upload", "https://clips.example/uploads/window-shot-design-review.jpg", WARNING, False, False),
    ]

    top = 436
    for name, detail, url, color, is_video, has_ocr in rows:
        box = (160, top, 1282, top + 92)
        draw_panel(draw, box, fill=CARD_ALT, outline=CARD_BORDER_SOFT, radius=24)
        draw_thumb(draw, (182, top + 14, 274, top + 78), color, is_video=is_video)
        draw.text((302, top + 16), fit_text(draw, name, BODY_FONT, 520), font=BODY_FONT, fill=TEXT)
        draw.text((302, top + 42), fit_text(draw, detail, SMALL_FONT, 520), font=SMALL_FONT, fill=TEXT_MUTED)
        draw.text((302, top + 66), fit_text(draw, url, SMALL_FONT, 620), font=SMALL_FONT, fill=URL)

        button_x = 1048
        draw_button(draw, button_x, top + 28, 68, "Copy", BLUE)
        button_x += 80
        draw_button(draw, button_x, top + 28, 68, "Open", GREEN)
        if has_ocr:
            draw_button(draw, button_x + 80, top + 28, 62, "OCR", GRAY_BUTTON)

        top += 106

    image.save(OUT_DIR / "clipforge-history-window.png")


def generate_demo_frames() -> list[Image.Image]:
    frames: list[Image.Image] = []

    frame = canvas()
    draw = ImageDraw.Draw(frame)
    draw_header(draw, "Clipforge Demo", "Capture, annotate, upload, copy, and move on.")
    popover = (972, 210, 1320, 656)
    draw_panel(draw, popover, radius=34)
    draw.text((1040, 250), "Capture", font=CARD_TITLE_FONT, fill=TEXT)
    top = 304
    for label in ["Capture Area", "Scroll Capture", "Record 8s Screen Clip", "Paste Clipboard Image"]:
        draw_panel(draw, (1000, top, 1288, top + 58), fill=CARD_ALT, outline=CARD_BORDER_SOFT, radius=20)
        draw.text((1022, top + 15), fit_text(draw, label, ACTION_FONT, 244), font=ACTION_FONT, fill=TEXT)
        top += 74
    frames.append(frame)

    frame = canvas().convert("RGBA")
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (6, 11, 18, 156))
    frame = Image.alpha_composite(frame, overlay)
    draw = ImageDraw.Draw(frame)
    draw_header(draw, "Clipforge Demo", "Capture, annotate, upload, copy, and move on.")
    draw.rounded_rectangle((238, 214, 930, 692), radius=28, outline=(137, 201, 255, 255), width=4)
    draw.rounded_rectangle((256, 232, 912, 674), radius=22, outline=(137, 201, 255, 110), width=2)
    draw.text((280, 728), "Choose an area, or switch to scroll capture when one screenshot is not enough.", font=BODY_FONT, fill=TEXT)
    frames.append(frame.convert("RGB"))

    frame = canvas()
    draw = ImageDraw.Draw(frame)
    draw_header(draw, "Clipforge Demo", "Capture, annotate, upload, copy, and move on.")
    editor = (162, 194, 1278, 820)
    draw_panel(draw, editor, radius=34)
    draw.text((202, 208), "Annotate Before Delivery", font=CARD_TITLE_FONT, fill=TEXT)
    draw_panel(draw, (202, 298, 1122, 736), radius=24, fill=(244, 247, 250), outline=(206, 216, 229))
    for index in range(8):
        y = 340 + (index * 40)
        draw.rounded_rectangle((246, y, 988, y + 16), radius=8, fill=(206 - index * 10, 214 - index * 8, 227 - index * 7))
    draw.rectangle((668, 404, 1010, 556), outline=(236, 113, 92), width=6)
    draw.line((426, 628, 760, 478), fill=ACCENT, width=8)
    draw.polygon([(760, 478), (729, 477), (742, 506)], fill=ACCENT)
    draw.rounded_rectangle((382, 446, 626, 512), radius=18, fill=(255, 236, 95, 170), outline=(215, 187, 61), width=3)

    button_labels = ["Arrow", "Box", "Highlight", "Pen", "Undo", "Continue"]
    x = 202
    for label in button_labels:
        draw_button(draw, x, 754, 126, label, BLUE if label == "Continue" else CARD_ALT)
        x += 138
    frames.append(frame)

    frame = canvas()
    draw = ImageDraw.Draw(frame)
    draw_header(draw, "Clipforge Demo", "Capture, annotate, upload, copy, and move on.")
    toast = (290, 286, 1150, 682)
    draw_panel(draw, toast, radius=34, fill=(15, 21, 31), outline=CARD_BORDER)
    success_title = load_font(48, bold=True, italic=True)
    draw.text((344, 334), "Upload complete", font=success_title, fill=TEXT)
    body_lines = [
        "Clipforge copied the Markdown image tag, kept the local file,",
        "and left OCR text ready for the next paste.",
    ]
    draw.multiline_text((344, 424), "\n".join(body_lines), font=BODY_FONT, fill=TEXT_MUTED, spacing=10)
    draw_panel(draw, (344, 518, 1096, 578), fill=CARD_ALT, outline=CARD_BORDER_SOFT, radius=18)
    snippet = "![scroll-capture](https://clips.example/share/scroll-capture-2026-03-29)"
    draw.text((368, 538), fit_text(draw, snippet, MONO_FONT, 704), font=MONO_FONT, fill=URL)
    draw_button(draw, 344, 606, 176, "Copy Text", SUCCESS)
    draw_button(draw, 534, 606, 176, "Open Link", BLUE)
    draw_button(draw, 724, 606, 176, "Reveal File", GRAY_BUTTON)
    frames.append(frame)

    return frames


def generate_demo_gif() -> None:
    frames = generate_demo_frames()
    converted = [frame.convert("P", palette=Image.ADAPTIVE, colors=160) for frame in frames]
    converted[0].save(
        OUT_DIR / "clipforge-demo.gif",
        save_all=True,
        append_images=converted[1:],
        duration=[1200, 1000, 1200, 1300],
        loop=0,
        disposal=2,
    )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    generate_menu_popover_png()
    generate_history_png()
    generate_demo_gif()
    print(f"Generated marketing assets in {OUT_DIR}")


if __name__ == "__main__":
    main()
