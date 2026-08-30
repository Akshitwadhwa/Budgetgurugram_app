from collections.abc import Generator
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy import DateTime, TypeDecorator, create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from core.config import get_settings


class Base(DeclarativeBase):
    pass


class UtcDateTime(TypeDecorator):
    """A timestamp that is always timezone-aware UTC in Python.

    Postgres ``timestamptz`` hands back aware datetimes; SQLite has no timezone
    type and hands back naive ones. Without this, the same expression
    (``row.fetched_at > datetime.now(UTC)``) works on Postgres and raises
    ``TypeError: can't compare offset-naive and offset-aware datetimes`` on
    SQLite — a whole class of bug that only appears on one backend.

    Normalising at the type boundary fixes every call site at once, rather than
    scattering ``.replace(tzinfo=...)`` through the codebase and missing some.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            # A naive value from a parser is treated as UTC rather than local:
            # guessing the machine's timezone would silently shift event times.
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=UTC)
        return value.astimezone(UTC)


engine = None
SessionLocal = None


def configure_engine(url: str | None = None) -> None:
    global engine, SessionLocal
    resolved = url or get_settings().sqlalchemy_url
    kwargs: dict = {"pool_pre_ping": True}

    if resolved.startswith("sqlite"):
        # The API and the worker are separate processes writing one file.
        # WAL plus a busy timeout is what makes that safe rather than a source
        # of "database is locked" failures under concurrent writes.
        kwargs["connect_args"] = {"check_same_thread": False, "timeout": 30}
        ensure_sqlite_dir(resolved)

    engine = create_engine(resolved, **kwargs)

    if resolved.startswith("sqlite"):

        @event.listens_for(engine, "connect")
        def _sqlite_pragmas(dbapi_connection, _record):  # pragma: no cover - driver hook
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA busy_timeout=30000")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, expire_on_commit=False)


def ensure_sqlite_dir(url: str) -> None:
    """Create the parent directory for a file-backed SQLite database."""
    path = url.split("///", 1)[-1]
    if path and path != ":memory:":
        Path(path).expanduser().resolve().parent.mkdir(parents=True, exist_ok=True)


def get_session_factory():
    if SessionLocal is None:
        configure_engine()
    assert SessionLocal is not None
    return SessionLocal


def get_session() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
