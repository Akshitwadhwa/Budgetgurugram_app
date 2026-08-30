from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

import httpx
from bs4 import BeautifulSoup
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
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
    description: str = ""


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


def html_to_text(html: str | bytes) -> tuple[str, str]:
    # Parse from raw bytes where possible so BeautifulSoup can detect the
    # charset from the document's own meta tags. httpx's `.text` guesses from
    # headers alone and silently mangles en-dashes and smart quotes into U+FFFD,
    # which then end up inside evidence quotes shown to users.
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
    title, content = html_to_text(response.content)
    if not content:
        return None
    # Extracted here because the bytes are already in hand; asking for it later
    # would mean fetching the same page a second time.
    from worker.sources.parse import extract_description

    return FetchedPage(
        url=str(response.url),
        title=title,
        content=content,
        content_hash=_hash(content),
        description=extract_description(response.content),
    )


def cache_document(session: Session, page: FetchedPage) -> WebDocument:
    now = datetime.now(timezone.utc)

    # Objects added earlier in this transaction are not yet visible to a SELECT,
    # so a URL reached twice in one research pass (e.g. the same organiser page
    # returned by two different queries) would be inserted twice and violate the
    # unique index on flush. Check the pending set first.
    for pending in session.new:
        if isinstance(pending, WebDocument) and pending.url == page.url:
            return pending

    existing = session.scalar(select(WebDocument).where(WebDocument.url == page.url))
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

    # Insert inside a savepoint and flush immediately. Two reasons:
    #
    #  * The row becomes visible to later SELECTs in this transaction, so the
    #    duplicate is caught here rather than blowing up the whole batch at
    #    commit time - one repeated URL used to lose every document and every
    #    verdict for that event.
    #  * If a unique violation still happens (a redirect collapsing two URLs
    #    onto one, a concurrent worker), only the savepoint rolls back and we
    #    fall back to the row that is already there.
    try:
        with session.begin_nested():
            session.add(doc)
            session.flush()
        return doc
    except IntegrityError:
        conflicting = session.scalar(select(WebDocument).where(WebDocument.url == page.url))
        if conflicting is not None:
            return conflicting
        raise
