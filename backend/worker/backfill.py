from __future__ import annotations

import argparse
import logging

from sqlalchemy import select

from core.db import get_session_factory
from core.models import Organizer, Source
from worker.sources import adapter_for
from worker.stages.discover import upsert_event
from worker.stages.enrich import enrich_pending
from worker.stages.index import index_events
from worker.stages.research import research_new_events
from worker.stages.resolve import resolve_unlinked
from worker.stages.sweep import sweep

log = logging.getLogger(__name__)


def backfill(*, organizers_from_live: bool, limit: int | None) -> None:
    session = get_session_factory()()
    try:
        organizers = session.scalars(select(Organizer).order_by(Organizer.first_seen_at.asc())).all()
        if limit is not None:
            organizers = organizers[:limit]
        if not organizers_from_live:
            log.info("nothing to do without --organizers-from-live")
            return

        for organizer in organizers:
            source = session.get(Source, organizer.source_id) if organizer.source_id else None
            if source is None or not organizer.source_ref:
                continue
            try:
                adapter = adapter_for(source.id)
                found = adapter.fetch_organizer_history(organizer.source_ref, source.config or {})
            except Exception:
                log.exception("backfill failed for organizer %s", organizer.id)
                continue
            for item in found:
                upsert_event(session, item)
            session.commit()

        resolve_unlinked(session)
        session.commit()
        research_new_events(session)
        session.commit()
        enrich_pending(session)
        session.commit()
        index_events(session)
        session.commit()
        sweep(session)
        session.commit()
    finally:
        session.close()


def main() -> None:
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(description="Backfill organizer history. Partial is acceptable.")
    parser.add_argument("--organizers-from-live", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()
    backfill(organizers_from_live=args.organizers_from_live, limit=args.limit)


if __name__ == "__main__":
    main()
