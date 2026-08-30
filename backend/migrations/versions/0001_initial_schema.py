"""Initial event-intelligence schema.

Revision ID: 0001_initial
Revises:
Create Date: 2026-08-30
"""

import sqlalchemy as sa
from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


SEED_SOURCES = [
    ("luma", "Luma", {"url": "https://lu.ma/gurugram"}),
    ("meetup", "Meetup", {"url": "https://www.meetup.com/find/in--gurgaon/"}),
    ("community", "CommunityMeetups", {"url": "https://lu.ma/CommunityMeetups"}),
]


def _upgrade_portable(bind) -> None:
    """Schema for non-Postgres backends (SQLite).

    Built from the ORM models rather than hand-written DDL, so the two can
    never drift. The Postgres path below keeps its explicit SQL because it
    carries things the models cannot express portably - notably the
    ``jsonb_array_length(evidence) > 0`` check and the trigram indexes.
    """
    from core.db import Base
    from core import models  # noqa: F401  (registers the tables on Base)

    Base.metadata.create_all(bind)
    sources = Base.metadata.tables["sources"]
    existing = {row[0] for row in bind.execute(sa.select(sources.c.id))}
    rows = [
        {"id": sid, "display_name": name, "enabled": True, "config": config}
        for sid, name, config in SEED_SOURCES
        if sid not in existing
    ]
    if rows:
        bind.execute(sources.insert(), rows)


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        _upgrade_portable(bind)
        return

    op.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
    op.execute(
        """
        CREATE TABLE sources (
          id            text PRIMARY KEY,
          display_name  text NOT NULL,
          enabled       boolean NOT NULL DEFAULT true,
          config        jsonb NOT NULL DEFAULT '{}'::jsonb,
          created_at    timestamptz NOT NULL DEFAULT now()
        );

        CREATE TABLE organizers (
          id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          source_id         text REFERENCES sources(id),
          source_ref        text,
          name              text NOT NULL,
          normalized_name   text NOT NULL,
          url               text,
          socials           jsonb NOT NULL DEFAULT '[]'::jsonb,
          profile_summary   text,
          profile_evidence  jsonb NOT NULL DEFAULT '[]'::jsonb,
          embedding         jsonb,
          first_seen_at     timestamptz NOT NULL DEFAULT now(),
          last_seen_at      timestamptz NOT NULL DEFAULT now(),
          UNIQUE (source_id, source_ref)
        );
        CREATE INDEX organizers_name_trgm ON organizers USING gin (normalized_name gin_trgm_ops);

        CREATE TABLE series (
          id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          organizer_id       uuid REFERENCES organizers(id),
          canonical_title    text NOT NULL,
          normalized_key     text NOT NULL,
          format_verdict     text,
          format_confidence  real,
          level              text,
          cadence            text,
          typical_attendance int,
          summary            text,
          evidence           jsonb NOT NULL DEFAULT '[]'::jsonb,
          embedding          jsonb,
          editions_count     int NOT NULL DEFAULT 0,
          first_seen_at      timestamptz NOT NULL DEFAULT now(),
          last_seen_at       timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX series_key_trgm ON series USING gin (normalized_key gin_trgm_ops);

        CREATE TABLE events (
          id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          source_id        text NOT NULL REFERENCES sources(id),
          source_event_id  text NOT NULL,
          series_id        uuid REFERENCES series(id),
          organizer_id     uuid REFERENCES organizers(id),
          title            text NOT NULL,
          description_raw  text NOT NULL DEFAULT '',
          starts_at        timestamptz NOT NULL,
          ends_at          timestamptz,
          venue_name       text,
          address          text,
          lat              double precision,
          lng              double precision,
          geocode_quality  text,
          price_raw        text,
          price_value      numeric,
          url              text NOT NULL,
          city             text NOT NULL DEFAULT 'Gurugram',
          status           text NOT NULL DEFAULT 'upcoming',
          raw              jsonb NOT NULL,
          embedding        jsonb,
          first_seen_at    timestamptz NOT NULL DEFAULT now(),
          last_seen_at     timestamptz NOT NULL DEFAULT now(),
          UNIQUE (source_id, source_event_id)
        );
        CREATE INDEX events_starts_at ON events (starts_at);
        CREATE INDEX events_series ON events (series_id);

        CREATE TABLE event_enrichment (
          event_id          uuid PRIMARY KEY REFERENCES events(id) ON DELETE CASCADE,
          true_format       text NOT NULL,
          format_confidence real NOT NULL CHECK (format_confidence BETWEEN 0 AND 1),
          level             text,
          hands_on          boolean,
          expect            text NOT NULL,
          who_should_come   jsonb NOT NULL DEFAULT '[]'::jsonb,
          prep_needed       text,
          watch_outs        jsonb NOT NULL DEFAULT '[]'::jsonb,
          evidence          jsonb NOT NULL,
          escalated         boolean NOT NULL DEFAULT false,
          model             text NOT NULL,
          prompt_version    text NOT NULL,
          tokens_in         int,
          tokens_out        int,
          created_at        timestamptz NOT NULL DEFAULT now(),
          CONSTRAINT evidence_required CHECK (jsonb_array_length(evidence) > 0)
        );

        CREATE TABLE web_documents (
          id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          url          text NOT NULL UNIQUE,
          title        text,
          content      text NOT NULL,
          content_hash text NOT NULL,
          fetched_at   timestamptz NOT NULL DEFAULT now()
        );

        CREATE TABLE event_chunks (
          id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          event_id     uuid REFERENCES events(id) ON DELETE CASCADE,
          series_id    uuid REFERENCES series(id) ON DELETE CASCADE,
          source_type  text NOT NULL,
          source_url   text,
          content      text NOT NULL,
          embedding    jsonb NOT NULL,
          created_at   timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX event_chunks_event ON event_chunks (event_id);

        CREATE TABLE event_similarity (
          event_id      uuid REFERENCES events(id) ON DELETE CASCADE,
          similar_id    uuid REFERENCES events(id) ON DELETE CASCADE,
          score         real NOT NULL,
          PRIMARY KEY (event_id, similar_id)
        );

        CREATE TABLE devices (
          id            text PRIMARY KEY,
          first_seen_at timestamptz NOT NULL DEFAULT now(),
          last_seen_at  timestamptz NOT NULL DEFAULT now(),
          blocked       boolean NOT NULL DEFAULT false
        );

        CREATE TABLE qa_messages (
          id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          device_id    text NOT NULL REFERENCES devices(id),
          event_id     uuid NOT NULL REFERENCES events(id),
          question     text NOT NULL,
          question_key text NOT NULL,
          answer       text,
          citations    jsonb NOT NULL DEFAULT '[]'::jsonb,
          refused      boolean NOT NULL DEFAULT false,
          tokens_in    int,
          tokens_out   int,
          created_at   timestamptz NOT NULL DEFAULT now()
        );
        CREATE INDEX qa_device_day ON qa_messages (device_id, created_at);
        CREATE INDEX qa_cache ON qa_messages (event_id, question_key);

        CREATE TABLE ingest_runs (
          id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          source_id       text NOT NULL REFERENCES sources(id),
          started_at      timestamptz NOT NULL DEFAULT now(),
          finished_at     timestamptz,
          status          text NOT NULL DEFAULT 'running',
          events_found    int NOT NULL DEFAULT 0,
          events_new      int NOT NULL DEFAULT 0,
          events_enriched int NOT NULL DEFAULT 0,
          search_calls    int NOT NULL DEFAULT 0,
          errors          jsonb NOT NULL DEFAULT '[]'::jsonb
        );
        """
    )
    op.execute(
        """
        INSERT INTO sources (id, display_name, enabled, config) VALUES
        (
          'luma',
          'Luma',
          true,
          '{"queries": ["gurugram", "gurgaon"]}'::jsonb
        ),
        (
          'meetup',
          'Meetup',
          true,
          '{"url": "https://www.meetup.com/find/in--gurgaon/"}'::jsonb
        ),
        (
          'community',
          'CommunityMeetups',
          true,
          '{"url": "https://lu.ma/CommunityMeetups"}'::jsonb
        );
        """
    )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name != "postgresql":
        from core.db import Base
        from core import models  # noqa: F401

        Base.metadata.drop_all(bind)
        return

    op.execute(
        """
        DROP TABLE IF EXISTS ingest_runs;
        DROP TABLE IF EXISTS qa_messages;
        DROP TABLE IF EXISTS devices;
        DROP TABLE IF EXISTS event_similarity;
        DROP TABLE IF EXISTS event_chunks;
        DROP TABLE IF EXISTS web_documents;
        DROP TABLE IF EXISTS event_enrichment;
        DROP TABLE IF EXISTS events;
        DROP TABLE IF EXISTS series;
        DROP TABLE IF EXISTS organizers;
        DROP TABLE IF EXISTS sources;
        """
    )
