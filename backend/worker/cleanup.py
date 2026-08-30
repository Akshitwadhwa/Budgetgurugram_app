"""Remove event rows that should never have been stored.

Two classes of bad row, both from bugs now fixed upstream:

1. **Un-fetchable URLs** - CommunityMeetups stored Luma's bare slug
   ("m0o37oik") instead of a URL, producing rows that can never be researched
   and that duplicate the correctly-stored version of the same event.
2. **Out-of-city events** - nothing enforced the Gurugram-only rule, so an
   all-India calendar filed Bengaluru, Mumbai, Surat and Nagpur events here.

Reports by default; only writes with ``--apply``. Deleting is safe: discover
recreates anything that is still legitimately listed.

    python -m worker.cleanup
    python -m worker.cleanup --apply
"""

from __future__ import annotations

import argparse
import logging
from urllib.parse import urlparse

from sqlalchemy import select

from core.city_filter import city_verdict
from core.config import get_settings
from core.db import configure_engine, get_session_factory
from core.models import Event, EventChunk, EventEnrichment, EventSimilarity

log = logging.getLogger(__name__)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Actually delete. Default is a report.")
    args = parser.parse_args()

    logging.basicConfig(level=logging.WARNING)
    settings = get_settings()
    configure_engine()
    session = get_session_factory()()

    try:
        events = session.scalars(select(Event)).all()
        bad_url: list[Event] = []
        wrong_city: list[tuple[Event, str]] = []

        for event in events:
            parsed = urlparse(event.url or "")
            if parsed.scheme not in {"http", "https"} or not parsed.netloc:
                bad_url.append(event)
                continue
            keep, reason = city_verdict(
                title=event.title,
                location=" ".join(
                    part for part in (event.venue_name, event.address) if part
                ),
                lat=event.lat,
                lng=event.lng,
                geocode_quality=event.geocode_quality,
                city_slugs=settings.city_slug_list,
                bbox=settings.bbox,
            )
            if not keep:
                wrong_city.append((event, reason))

        print(f"{len(events)} event rows\n")

        print(f"un-fetchable URL ({len(bad_url)}):")
        for event in bad_url:
            print(f"   {event.title[:52]:52s}  url={event.url!r}")

        print(f"\nout-of-city ({len(wrong_city)}):")
        for event, reason in wrong_city:
            print(f"   {event.title[:52]:52s}  {reason}")

        doomed = [e for e in bad_url] + [e for e, _ in wrong_city]
        enriched = sum(
            1 for e in doomed if session.get(EventEnrichment, e.id) is not None
        )
        print(f"\ntotal to remove: {len(doomed)} ({enriched} of them already enriched)")

        if not args.apply:
            print("\nreport only - pass --apply to delete")
            return

        for event in doomed:
            session.query(EventChunk).filter(EventChunk.event_id == event.id).delete()
            session.query(EventSimilarity).filter(
                (EventSimilarity.event_id == event.id)
                | (EventSimilarity.similar_id == event.id)
            ).delete()
            enrichment = session.get(EventEnrichment, event.id)
            if enrichment is not None:
                session.delete(enrichment)
            session.delete(event)
        session.commit()
        print(f"\ndeleted {len(doomed)} row(s); {len(events) - len(doomed)} remain")
    finally:
        session.close()


if __name__ == "__main__":
    main()
