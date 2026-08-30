from __future__ import annotations

import logging

from sqlalchemy import select
from sqlalchemy.orm import Session

from core.db import get_session_factory
from core.models import Source
from worker.stages.discover import discover_source
from worker.stages.enrich import enrich_pending
from worker.stages.index import index_events
from worker.stages.research import research_new_events
from worker.stages.resolve import resolve_unlinked
from worker.stages.sweep import sweep

log = logging.getLogger(__name__)


def run_pipeline() -> None:
    session: Session = get_session_factory()()
    try:
        sources = session.scalars(select(Source).where(Source.enabled.is_(True))).all()
        last_ok_run = None
        for source in sources:
            try:
                run = discover_source(session, source)
                session.commit()
                if run.status == "ok":
                    last_ok_run = run
            except Exception:
                session.rollback()
                log.exception("discover failed for %s", source.id)

        resolve_unlinked(session)
        session.commit()
        research_new_events(session, last_ok_run)
        session.commit()
        enrich_pending(session, last_ok_run)
        session.commit()
        index_events(session)
        session.commit()
        sweep(session)
        session.commit()
    except Exception:
        session.rollback()
        log.exception("pipeline failed")
        raise
    finally:
        session.close()
