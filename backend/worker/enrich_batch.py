"""Run research + enrichment over a bounded number of events.

`worker.run` enriches everything it finds, which is right for a scheduled
worker and wrong for the first time you point real money at a new prompt. This
runs a fixed-size batch and reports what it cost, so quality and spend can be
checked before scaling up.

    python -m worker.enrich_batch --limit 3
    python -m worker.enrich_batch --limit 3 --dry-run     # research only, no LLM verdicts
    python -m worker.enrich_batch --limit 50

Prices are per 1M tokens and must be kept in step with the configured model.
"""

from __future__ import annotations

import argparse
import logging

from sqlalchemy import select

from core.config import get_settings
from core.db import configure_engine, get_session_factory
from core.models import Event, EventChunk, EventEnrichment
from worker.stages.enrich import enrich_event
from worker.stages.research import research_event

log = logging.getLogger(__name__)

# USD per 1M tokens, input/output.
PRICES = {
    "gpt-5.6-sol": (5.00, 30.00),
    "gpt-5.6-terra": (2.00, 12.00),
    "gpt-5.6-luna": (0.20, 1.20),
}


def _cost(model: str, tokens_in: int, tokens_out: int) -> float:
    price_in, price_out = PRICES.get(model, (0.0, 0.0))
    return (tokens_in / 1_000_000) * price_in + (tokens_out / 1_000_000) * price_out


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=3)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Research and embed only; skip the paid verdict call.",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    settings = get_settings()
    configure_engine()
    session = get_session_factory()()

    try:
        pending = session.scalars(
            select(Event)
            .where(
                Event.id.notin_(select(EventEnrichment.event_id)),
                Event.status == "upcoming",
            )
            .order_by(Event.starts_at)
            .limit(args.limit)
        ).all()

        if not pending:
            print("Nothing to enrich — every upcoming event already has a verdict.")
            return

        print(f"Selected {len(pending)} event(s). Model: {settings.openai_model_enrich}\n")

        succeeded = 0
        for index, event in enumerate(pending, start=1):
            print(f"[{index}/{len(pending)}] {event.title[:70]}")

            existing = session.scalar(
                select(EventChunk).where(EventChunk.event_id == event.id).limit(1)
            )
            if existing is None:
                try:
                    research_event(session, event, None)
                    session.commit()
                except Exception as exc:  # noqa: BLE001 - reported, not swallowed
                    print(f"    research failed: {type(exc).__name__}: {exc}")
                    session.rollback()
                    continue

            chunks = session.scalars(
                select(EventChunk).where(EventChunk.event_id == event.id)
            ).all()
            sources = {c.source_url for c in chunks if c.source_url}
            print(f"    {len(chunks)} chunk(s) from {len(sources)} source(s)")

            if not chunks:
                print("    no material to cite — skipping (a verdict without evidence is not allowed)")
                continue

            if args.dry_run:
                continue

            if enrich_event(session, event, None, retry=True):
                session.commit()
                succeeded += 1
                row = session.get(EventEnrichment, event.id)
                if row is not None:
                    print(
                        f"    -> {row.true_format} @ {row.format_confidence:.2f} "
                        f"({len(row.evidence)} evidence, "
                        f"{row.tokens_in}+{row.tokens_out} tokens)"
                    )
            else:
                session.rollback()
                print("    -> rejected (see warnings above)")

        rows = session.scalars(select(EventEnrichment)).all()
        tokens_in = sum(r.tokens_in or 0 for r in rows)
        tokens_out = sum(r.tokens_out or 0 for r in rows)
        spend = sum(
            _cost(r.model, r.tokens_in or 0, r.tokens_out or 0) for r in rows
        )

        print(f"\nenriched this run: {succeeded}/{len(pending)}")
        print(f"total verdicts in db: {len(rows)}")
        print(f"total tokens: {tokens_in} in / {tokens_out} out")
        print(f"estimated total spend: ${spend:.4f}")
        if rows:
            print(f"average per verdict: ${spend / len(rows):.4f}")
    finally:
        session.close()


if __name__ == "__main__":
    main()
