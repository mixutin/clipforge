from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
import re
from urllib.parse import quote


@dataclass(frozen=True)
class ShareMetadata:
    title: str
    description: str
    site_name: str
    direct_url: str
    share_url: str
    media_kind: str
    theme_color: str | None


class _SafeTemplateContext(dict[str, str]):
    def __missing__(self, key: str) -> str:
        return "{" + key + "}"


def build_share_url(base_url: str, filename: str) -> str:
    return f"{base_url}/share/{quote(filename)}"


def render_share_template(template: str, context: dict[str, str]) -> str:
    try:
        return template.format_map(_SafeTemplateContext(context)).strip()
    except ValueError:
        return template.strip()


def normalize_theme_color(value: str) -> str | None:
    trimmed = value.strip()
    if not trimmed:
        return None

    if re.fullmatch(r"#?[0-9a-fA-F]{6}", trimmed) is None:
        return None

    return trimmed if trimmed.startswith("#") else f"#{trimmed}"


def make_share_context(filename: str, direct_url: str, share_url: str) -> dict[str, str]:
    return {
        "filename": filename,
        "basename": Path(filename).stem,
        "direct_url": direct_url,
        "share_url": share_url,
    }


def build_share_page_html(metadata: ShareMetadata) -> str:
    title = escape(metadata.title, quote=True)
    description = escape(metadata.description, quote=True)
    site_name = escape(metadata.site_name, quote=True)
    direct_url = escape(metadata.direct_url, quote=True)
    share_url = escape(metadata.share_url, quote=True)
    theme_color = escape(metadata.theme_color, quote=True) if metadata.theme_color else None
    theme_meta = f'<meta name="theme-color" content="{theme_color}">' if theme_color else ""
    is_video = metadata.media_kind == "video"
    og_type = "video.other" if is_video else "website"
    media_meta = (
        f'<meta property="og:video" content="{direct_url}">\n'
        f'    <meta property="og:video:type" content="video/mp4">\n'
        f'    <meta name="twitter:card" content="player">\n'
        f'    <meta name="twitter:player" content="{share_url}">\n'
        if is_video else
        f'<meta property="og:image" content="{direct_url}">\n'
        f'    <meta name="twitter:card" content="summary_large_image">\n'
        f'    <meta name="twitter:image" content="{direct_url}">\n'
    )
    media_markup = (
        f'<video src="{direct_url}" controls playsinline preload="metadata"></video>'
        if is_video else
        f'<img src="{direct_url}" alt="{title}">'
    )
    primary_action = "Open clip" if is_video else "Open image"

    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{title}</title>
    <meta name="description" content="{description}">
    <meta name="robots" content="noindex">
    <link rel="canonical" href="{share_url}">
    <meta property="og:title" content="{title}">
    <meta property="og:description" content="{description}">
    <meta property="og:type" content="{og_type}">
    {media_meta.rstrip()}
    <meta property="og:url" content="{share_url}">
    <meta property="og:site_name" content="{site_name}">
    <meta name="twitter:title" content="{title}">
    <meta name="twitter:description" content="{description}">
    {theme_meta}
    <style>
      :root {{
        color-scheme: dark;
        --bg: #0f1115;
        --panel: #171a21;
        --text: #f5f7fa;
        --muted: #98a2b3;
        --accent: #79b8ff;
      }}

      * {{
        box-sizing: border-box;
      }}

      body {{
        margin: 0;
        padding: 40px 20px;
        background: radial-gradient(circle at top, #1b2130, var(--bg) 55%);
        color: var(--text);
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }}

      main {{
        max-width: 820px;
        margin: 0 auto;
      }}

      .card {{
        background: rgba(23, 26, 33, 0.92);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 20px;
        overflow: hidden;
        box-shadow: 0 24px 80px rgba(0, 0, 0, 0.35);
      }}

      .copy {{
        padding: 24px 24px 0;
      }}

      h1 {{
        margin: 0 0 10px;
        font-size: 28px;
      }}

      p {{
        margin: 0;
        color: var(--muted);
        line-height: 1.6;
      }}

      img,
      video {{
        display: block;
        width: 100%;
        height: auto;
        margin-top: 24px;
        background: #0b0d11;
      }}

      .actions {{
        display: flex;
        gap: 12px;
        flex-wrap: wrap;
        padding: 20px 24px 24px;
      }}

      a.button {{
        display: inline-flex;
        align-items: center;
        gap: 8px;
        padding: 10px 14px;
        border-radius: 999px;
        text-decoration: none;
        color: var(--text);
        background: rgba(255, 255, 255, 0.08);
      }}

      a.button.primary {{
        background: var(--accent);
        color: #08111e;
        font-weight: 600;
      }}
    </style>
  </head>
  <body>
    <main>
      <div class="card">
        <div class="copy">
          <h1>{title}</h1>
          <p>{description}</p>
        </div>
        {media_markup}
        <div class="actions">
          <a class="button primary" href="{direct_url}">{primary_action}</a>
          <a class="button" href="{share_url}">Share page</a>
        </div>
      </div>
    </main>
  </body>
</html>
"""
