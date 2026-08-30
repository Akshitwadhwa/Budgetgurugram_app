"""Dump the database to a single readable JSON file.

SQLite is the engine — one file, no server, no extensions — but a `.db` is not
something you can open in an editor. This command produces the human-readable
view: one JSON document you can read, diff, grep, or hand to someone else.

    python -m worker.export_json
    python -m worker.export_json --out data/export.json --include-embeddings

Events are exported **nested** — each event carries its verdict, its evidence,
its series and its past editions — because that is how the data is actually
read. A flat table dump would be faithful to the schema and useless to a human.

Embeddings are excluded by default. A single one is 1536 floats; including them
turns a readable document into 40MB of noise. `--include-embeddings` is there
for when you genuinely need to inspect vectors.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import tempfile
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from core import models
from core.confidence import confidence_band
from core.db import configure_engine, get_session_factory

log = logging.getLogger(__name__)

DEFAULT_OUT = Path("data/export.json")


def _plain(value: Any) -> Any:
    """Make a value JSON-serialisable without losing precision."""
    if isinstance(value, datetime):
        return value.isoformat()
    if isinstance(value, UUID):
        return str(value)
    if isinstance(value, Decimal):
        return float(value)
    return value


def _row(obj: Any, *, skip: set[str] = frozenset()) -> dict[str, Any]:
    return {
        column.key: _plain(getattr(obj, column.key))
        for column in obj.__table__.columns
        if column.key not in skip
    }


def build_export(session: Session, *, include_embeddings: bool = False) -> dict[str, Any]:
    skip: set[str] = set() if include_embeddings else {"embedding"}

    sources = session.scalars(select(models.Source)).all()
    organizers = session.scalars(select(models.Organizer)).all()
    series_rows = session.scalars(select(models.Series)).all()
    events = session.scalars(select(models.Event).order_by(models.Event.starts_at)).all()
    enrichments = session.scalars(select(models.EventEnrichment)).all()
    similarity = session.scalars(select(models.EventSimilarity)).all()
    web_docs = session.scalars(select(models.WebDocument)).all()
    runs = session.scalars(
        select(models.IngestRun).order_by(models.IngestRun.started_at.desc())
    ).all()

    by_event = {e.event_id: e for e in enrichments}
    series_by_id = {s.id: s for s in series_rows}
    organizer_by_id = {o.id: o for o in organizers}
    titles = {e.id: e.title for e in events}

    similar_by_event: dict[UUID, list[dict[str, Any]]] = {}
    for link in similarity:
        similar_by_event.setdefault(link.event_id, []).append(
            {
                "id": str(link.similar_id),
                "title": titles.get(link.similar_id),
                "score": link.score,
            }
        )

    editions: dict[UUID, list[dict[str, Any]]] = {}
    for event in events:
        if event.series_id is not None:
            editions.setdefault(event.series_id, []).append(
                {
                    "id": str(event.id),
                    "title": event.title,
                    "startsAt": _plain(event.starts_at),
                    "url": event.url,
                }
            )

    exported_events = []
    for event in events:
        row = _row(event, skip=skip | {"raw"})
        enrichment = by_event.get(event.id)

        if enrichment is not None:
            verdict = _row(enrichment, skip={"event_id"})
            # The band is what the app renders; exporting it means the file
            # shows the same judgement the UI shows, not a raw float the
            # reader has to threshold themselves.
            verdict["band"] = confidence_band(enrichment.format_confidence)
            row["verdict"] = verdict
        else:
            row["verdict"] = None

        series = series_by_id.get(event.series_id) if event.series_id else None
        if series is not None:
            row["series"] = {
                **_row(series, skip=skip),
                "pastEditions": [
                    edition
                    for edition in editions.get(series.id, [])
                    if edition["id"] != str(event.id)
                ],
            }
            organizer = organizer_by_id.get(series.organizer_id) if series.organizer_id else None
            row["series"]["organizer"] = _row(organizer, skip=skip) if organizer else None
        else:
            row["series"] = None

        row["similar"] = sorted(
            similar_by_event.get(event.id, []),
            key=lambda item: item["score"],
            reverse=True,
        )
        exported_events.append(row)

    return {
        "exportedAt": datetime.now(UTC).isoformat(),
        "includesEmbeddings": include_embeddings,
        "counts": {
            "sources": len(sources),
            "organizers": len(organizers),
            "series": len(series_rows),
            "events": len(events),
            "enrichedEvents": len(enrichments),
            "webDocuments": len(web_docs),
            "ingestRuns": len(runs),
        },
        "sources": [_row(s) for s in sources],
        "organizers": [_row(o, skip=skip) for o in organizers],
        "series": [_row(s, skip=skip) for s in series_rows],
        "events": exported_events,
        "webDocuments": [_row(d, skip={"content"}) for d in web_docs],
        "ingestRuns": [_row(r) for r in runs],
    }


def write_export(payload: dict[str, Any], out: Path) -> Path:
    """Write atomically, so a reader never sees a half-written file."""
    out.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(dir=str(out.parent), suffix=".tmp")
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
        tmp.replace(out)
    except BaseException:
        tmp.unlink(missing_ok=True)
        raise
    return out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--include-embeddings",
        action="store_true",
        help="Include raw 1536-dim vectors (makes the file very large).",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO)
    configure_engine()
    with get_session_factory()() as session:
        payload = build_export(session, include_embeddings=args.include_embeddings)

    out = write_export(payload, args.out)
    counts = payload["counts"]
    log.info(
        "wrote %s (%d events, %d enriched, %d series)",
        out,
        counts["events"],
        counts["enrichedEvents"],
        counts["series"],
    )


if __name__ == "__main__":
    main()
