"""Fill in missing event descriptions from their listing pages.

Neither discover source provides one: Meetup's JSON-LD carries an empty
``description``, and Luma's discover API omits the field. Without this, events
reach the app with a blank body.

    python -m worker.backfill_descriptions
    python -m worker.backfill_descriptions --limit 10 --force

Safe to re-run: it only touches rows whose description is empty, unless
``--force`` is given.
"""

from __future__ import annotations

import argparse
import logging

from sqlalchemy import or_, select

from core.db import configure_engine, get_session_factory
from core.models import Event
from core.websearch import fetch_page

log = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=500)
    parser.add_argument("--force", action="store_true", help="Refetch even if a description exists.")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    configure_engine()
    session = get_session_factory()()

    try:
        query = select(Event).order_by(Event.starts_at).limit(args.limit)
        if not args.force:
            query = select(Event).where(
                or_(Event.description_raw == "", Event.description_raw.is_(None))
            ).order_by(Event.starts_at).limit(args.limit)

        events = session.scalars(query).all()
        print(f"{len(events)} event(s) to process")

        filled = skipped = 0
        for index, event in enumerate(events, start=1):
            page = fetch_page(event.url)
            if page is None or not page.description:
                skipped += 1
                print(f"[{index}/{len(events)}] {event.title[:55]:55s} -> no description found")
                continue
            event.description_raw = page.description
            session.commit()
            filled += 1
            print(f"[{index}/{len(events)}] {event.title[:55]:55s} -> {len(page.description)} chars")

        print(f"\nfilled: {filled}, no description available: {skipped}")
    finally:
        session.close()


if __name__ == "__main__":
    main()
