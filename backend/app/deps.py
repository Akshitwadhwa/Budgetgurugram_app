from __future__ import annotations

from collections.abc import Generator
from datetime import datetime, timezone

from fastapi import Depends, Header, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from core.config import get_settings
from core.db import get_session_factory
from core.models import Device, QaMessage
from core.qa import questions_over_limit


def get_db() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_device(
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    session: Session = Depends(get_db),
) -> Device:
    if not x_device_id or not x_device_id.strip():
        raise HTTPException(status_code=400, detail="X-Device-Id is required")
    device_id = x_device_id.strip()
    device = session.get(Device, device_id)
    now = datetime.now(timezone.utc)
    if device is None:
        device = Device(id=device_id, first_seen_at=now, last_seen_at=now)
        session.add(device)
        session.flush()
    else:
        device.last_seen_at = now
    if device.blocked:
        raise HTTPException(status_code=403, detail="Device is blocked")
    return device


def enforce_qa_limit(
    device: Device = Depends(get_device),
    session: Session = Depends(get_db),
) -> Device:
    settings = get_settings()
    start_of_day = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    count = session.scalar(
        select(func.count()).select_from(QaMessage).where(
            QaMessage.device_id == device.id,
            QaMessage.created_at >= start_of_day,
        )
    ) or 0
    if questions_over_limit(int(count), settings.qa_daily_limit):
        raise HTTPException(
            status_code=429,
            detail="You've asked 20 questions today. Resets tomorrow.",
            headers={"Retry-After": "86400"},
        )
    return device
