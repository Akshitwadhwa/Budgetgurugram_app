from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Float,
    ForeignKey,
    Integer,
    Numeric,
    Text,
    UniqueConstraint,
    Uuid,
    func,
)
from sqlalchemy import false as sa_false
from sqlalchemy import text as sa_text
from sqlalchemy import true as sa_true
from sqlalchemy.orm import Mapped, mapped_column, relationship, validates

from core.db import Base, UtcDateTime


class Source(Base):
    __tablename__ = "sources"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    display_name: Mapped[str] = mapped_column(Text, nullable=False)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=sa_true())
    config: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False, default=dict)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())

    events: Mapped[list[Event]] = relationship(back_populates="source")


class Organizer(Base):
    __tablename__ = "organizers"
    __table_args__ = (UniqueConstraint("source_id", "source_ref"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    source_id: Mapped[str | None] = mapped_column(ForeignKey("sources.id"))
    source_ref: Mapped[str | None] = mapped_column(Text)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    normalized_name: Mapped[str] = mapped_column(Text, nullable=False)
    url: Mapped[str | None] = mapped_column(Text)
    socials: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    profile_summary: Mapped[str | None] = mapped_column(Text)
    profile_evidence: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    embedding: Mapped[list[float] | None] = mapped_column(JSON)
    first_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())


class Series(Base):
    __tablename__ = "series"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    organizer_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("organizers.id"))
    canonical_title: Mapped[str] = mapped_column(Text, nullable=False)
    normalized_key: Mapped[str] = mapped_column(Text, nullable=False)
    format_verdict: Mapped[str | None] = mapped_column(Text)
    format_confidence: Mapped[float | None] = mapped_column(Float)
    level: Mapped[str | None] = mapped_column(Text)
    cadence: Mapped[str | None] = mapped_column(Text)
    typical_attendance: Mapped[int | None] = mapped_column(Integer)
    summary: Mapped[str | None] = mapped_column(Text)
    evidence: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    embedding: Mapped[list[float] | None] = mapped_column(JSON)
    editions_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=sa_text("0"))
    first_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())

    organizer: Mapped[Organizer | None] = relationship()


class Event(Base):
    __tablename__ = "events"
    __table_args__ = (UniqueConstraint("source_id", "source_event_id"),)

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    source_id: Mapped[str] = mapped_column(ForeignKey("sources.id"), nullable=False)
    source_event_id: Mapped[str] = mapped_column(Text, nullable=False)
    series_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("series.id"))
    organizer_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("organizers.id"))
    title: Mapped[str] = mapped_column(Text, nullable=False)
    description_raw: Mapped[str] = mapped_column(Text, nullable=False, default="", server_default=sa_text("''"))
    starts_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False)
    ends_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    venue_name: Mapped[str | None] = mapped_column(Text)
    address: Mapped[str | None] = mapped_column(Text)
    lat: Mapped[float | None] = mapped_column()
    lng: Mapped[float | None] = mapped_column()
    geocode_quality: Mapped[str | None] = mapped_column(Text)
    price_raw: Mapped[str | None] = mapped_column(Text)
    price_value: Mapped[float | None] = mapped_column(Numeric)
    url: Mapped[str] = mapped_column(Text, nullable=False)
    city: Mapped[str] = mapped_column(Text, nullable=False, default="Gurugram", server_default=sa_text("'Gurugram'"))
    status: Mapped[str] = mapped_column(Text, nullable=False, default="upcoming", server_default=sa_text("'upcoming'"))
    raw: Mapped[dict[str, Any]] = mapped_column(JSON, nullable=False)
    embedding: Mapped[list[float] | None] = mapped_column(JSON)
    guest_count: Mapped[int | None] = mapped_column(Integer)
    guest_count_source: Mapped[str | None] = mapped_column(Text)
    guest_count_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    first_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())

    source: Mapped[Source] = relationship(back_populates="events")
    series: Mapped[Series | None] = relationship()
    organizer: Mapped[Organizer | None] = relationship()
    enrichment: Mapped[EventEnrichment | None] = relationship(back_populates="event", uselist=False)


class EventEnrichment(Base):
    __tablename__ = "event_enrichment"
    __table_args__ = (
        CheckConstraint("format_confidence BETWEEN 0 AND 1", name="format_confidence_range"),
    )

    event_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("events.id", ondelete="CASCADE"), primary_key=True)
    true_format: Mapped[str] = mapped_column(Text, nullable=False)
    format_confidence: Mapped[float] = mapped_column(Float, nullable=False)
    level: Mapped[str | None] = mapped_column(Text)
    hands_on: Mapped[bool | None] = mapped_column(Boolean)
    expect: Mapped[str] = mapped_column(Text, nullable=False)
    who_should_come: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    prep_needed: Mapped[str | None] = mapped_column(Text)
    watch_outs: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    evidence: Mapped[list[Any]] = mapped_column(JSON, nullable=False)
    escalated: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=sa_false())
    model: Mapped[str] = mapped_column(Text, nullable=False)
    prompt_version: Mapped[str] = mapped_column(Text, nullable=False)
    tokens_in: Mapped[int | None] = mapped_column(Integer)
    tokens_out: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())

    event: Mapped[Event] = relationship(back_populates="enrichment")

    @validates("evidence")
    def _evidence_required(self, _key: str, value: Any) -> Any:
        """A verdict cannot be persisted without at least one source.

        This was a Postgres CHECK (``jsonb_array_length(evidence) > 0``), which
        has no portable equivalent. Moving it to the ORM keeps the trust rule
        enforced on every backend rather than only on Postgres.
        """
        if not isinstance(value, list) or len(value) == 0:
            raise ValueError("event_enrichment.evidence must be a non-empty list")
        return value


class WebDocument(Base):
    __tablename__ = "web_documents"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    url: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    title: Mapped[str | None] = mapped_column(Text)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    content_hash: Mapped[str] = mapped_column(Text, nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())


class EventChunk(Base):
    __tablename__ = "event_chunks"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    event_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("events.id", ondelete="CASCADE"))
    series_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("series.id", ondelete="CASCADE"))
    source_type: Mapped[str] = mapped_column(Text, nullable=False)
    source_url: Mapped[str | None] = mapped_column(Text)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    embedding: Mapped[list[float]] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())


class EventSimilarity(Base):
    __tablename__ = "event_similarity"

    event_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("events.id", ondelete="CASCADE"), primary_key=True)
    similar_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("events.id", ondelete="CASCADE"), primary_key=True)
    score: Mapped[float] = mapped_column(Float, nullable=False)


class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(Text, primary_key=True)
    first_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    blocked: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=sa_false())


class QaMessage(Base):
    __tablename__ = "qa_messages"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    device_id: Mapped[str] = mapped_column(ForeignKey("devices.id"), nullable=False)
    event_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("events.id"), nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    question_key: Mapped[str] = mapped_column(Text, nullable=False)
    answer: Mapped[str | None] = mapped_column(Text)
    citations: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
    refused: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=sa_false())
    tokens_in: Mapped[int | None] = mapped_column(Integer)
    tokens_out: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())


class IngestRun(Base):
    __tablename__ = "ingest_runs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    source_id: Mapped[str] = mapped_column(ForeignKey("sources.id"), nullable=False)
    started_at: Mapped[datetime] = mapped_column(UtcDateTime, nullable=False, default=lambda: datetime.now(UTC), server_default=func.now())
    finished_at: Mapped[datetime | None] = mapped_column(UtcDateTime)
    status: Mapped[str] = mapped_column(Text, nullable=False, default="running", server_default=sa_text("'running'"))
    events_found: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=sa_text("0"))
    events_new: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=sa_text("0"))
    events_enriched: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=sa_text("0"))
    search_calls: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default=sa_text("0"))
    errors: Mapped[list[Any]] = mapped_column(JSON, nullable=False, default=list)
