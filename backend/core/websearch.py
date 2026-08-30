from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx
from bs4 import BeautifulSoup
from sqlalchemy import select
from sqlalchemy.orm import Session

from core.config import get_settings
from core.models import IngestRun, WebDocument

log = logging.getLogger(__name__)
USER_AGENT = "GurugramCommons event researcher/1.0 (+https://budgetgurugram.vercel.app)"
CACHE_TTL = timedelta(days=14)


@dataclass
class SearchHit:
    url: str
    title: str
    snippet: str


@dataclass
class FetchedPage:
    url: str
    title: str
    content: str
    content_hash: str


def _hash(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()


def increment_search_calls(session: Session, run: IngestRun | None) -> None:
    if run is None:
        return
    run.search_calls = (run.search_calls or 0) + 1


def search_web(query: str, session: Session, run: IngestRun | None, limit: int = 5) -> list[SearchHit]:
    increment_search_calls(session, run)
    settings = get_settings()
    if not settings.search_api_key:
        log.warning("SEARCH_API_KEY missing; skipping web search for %s", query)
        return []

    try:
        response = httpx.post(
            "https://api.tavily.com/search",
            json={"api_key": settings.search_api_key, "query": query, "max_results": limit},
            timeout=20,
        )
        response.raise_for_status()
        payload = response.json()
    except Exception as exc:
        log.warning("web search failed for %s: %s", query, exc)
        return []

    hits = []
    for item in payload.get("results") or []:
        url = item.get("url")
        if not url:
            continue
        hits.append(SearchHit(url=url, title=item.get("title") or "", snippet=item.get("content") or ""))
    return hits


def html_to_text(html: str) -> tuple[str, str]:
    soup = BeautifulSoup(html, "html.parser")
    title = soup.title.get_text(strip=True) if soup.title else ""
    for tag in soup(["script", "style", "noscript"]):
        tag.decompose()
    text = re.sub(r"\s+", " ", soup.get_text(" ", strip=True)).strip()
    return title, text[:80_000]


def fetch_page(url: str) -> FetchedPage | None:
    try:
        response = httpx.get(url, headers={"user-agent": USER_AGENT}, timeout=20, follow_redirects=True)
        response.raise_for_status()
    except Exception as exc:
        log.warning("fetch failed for %s: %s", url, exc)
        return None
    title, content = html_to_text(response.text)
    if not content:
        return None
    return FetchedPage(url=str(response.url), title=title, content=content, content_hash=_hash(content))


def cache_document(session: Session, page: FetchedPage) -> WebDocument:
    existing = session.scalar(select(WebDocument).where(WebDocument.url == page.url))
    now = datetime.now(timezone.utc)
    if existing and existing.content_hash == page.content_hash and existing.fetched_at > now - CACHE_TTL:
        return existing
    if existing:
        existing.title = page.title
        existing.content = page.content
        existing.content_hash = page.content_hash
        existing.fetched_at = now
        return existing
    doc = WebDocument(
        url=page.url,
        title=page.title,
        content=page.content,
        content_hash=page.content_hash,
        fetched_at=now,
    )
    session.add(doc)
    return doc
