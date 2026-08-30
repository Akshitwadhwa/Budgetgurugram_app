from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup

SKIPPED_SLUGS = {"pricing", "login", "signup", "signin", "create", "calendar", "communitymeetups", "discover", "startup"}


def parse_dt(value: Any) -> datetime | None:
    if not value:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    text = str(value).replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def text_of(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, (str, int, float)):
        return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", str(value))).strip()
    if isinstance(value, list):
        return ", ".join(part for part in (text_of(item) for item in value) if part)
    if isinstance(value, dict):
        return text_of(value.get("name") or value.get("address") or value.get("text") or "")
    return ""


def first(*values: Any) -> str:
    for value in values:
        rendered = text_of(value)
        if rendered:
            return rendered
    return ""


def number_of(*values: Any) -> float | None:
    for value in values:
        if value is None or value == "":
            continue
        try:
            return float(value)
        except (TypeError, ValueError):
            continue
    return None


def canonical_luma_url(value: str, base: str = "") -> str:
    try:
        parsed = urlparse(urljoin(base, value))
    except Exception:
        return ""
    host = parsed.hostname or ""
    if not re.search(r"(^|\.)luma\.com$", host, re.I) and not re.search(r"(^|\.)lu\.ma$", host, re.I):
        return urljoin(base, value)
    slug = parsed.path.lstrip("/").split("/")[0]
    return f"https://lu.ma/{slug}" if slug else ""


def find_luma_urls(html: str, source_url: str) -> list[str]:
    urls: set[str] = set()
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup.find_all(["a", "link", "meta"]):
        href = tag.get("href") or tag.get("content") or ""
        url = canonical_luma_url(href, source_url)
        if not url:
            continue
        slug = urlparse(url).path.lstrip("/").split("/")[0]
        if slug and slug.lower() not in SKIPPED_SLUGS:
            urls.add(url)
    for match in re.findall(r"https?://lu\.ma/[a-zA-Z0-9_-]+", html):
        url = canonical_luma_url(match)
        slug = urlparse(url).path.lstrip("/").split("/")[0]
        if slug and slug.lower() not in SKIPPED_SLUGS:
            urls.add(url)
    return list(urls)[:80]


def parse_json_scripts(html: str) -> list[Any]:
    soup = BeautifulSoup(html, "html.parser")
    objects: list[Any] = []
    for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
        raw = script.string or script.get_text()
        try:
            objects.append(json.loads(raw))
        except json.JSONDecodeError:
            continue
    next_data = soup.find("script", id="__NEXT_DATA__")
    if next_data and (next_data.string or next_data.get_text()):
        try:
            objects.append(json.loads(next_data.string or next_data.get_text()))
        except json.JSONDecodeError:
            pass
    return objects


def collect_events(value: Any, output: list[dict] | None = None) -> list[dict]:
    output = output if output is not None else []
    if value is None:
        return output
    if isinstance(value, list):
        for item in value:
            collect_events(item, output)
        return output
    if not isinstance(value, dict):
        return output
    types = value.get("@type")
    types = types if isinstance(types, list) else [types]
    if any(str(item).lower() == "event" for item in types) or (
        value.get("name") and (value.get("startDate") or value.get("start_time") or value.get("start_at"))
    ):
        output.append(value)
    for item in value.values():
        if isinstance(item, (dict, list)):
            collect_events(item, output)
    return output
