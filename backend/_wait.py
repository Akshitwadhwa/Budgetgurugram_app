import time
from sqlalchemy import select, func
from core.db import configure_engine, get_session_factory
from core.models import EventEnrichment, Event
configure_engine()
S = get_session_factory()
prev = -1
for _ in range(180):
    with S() as s:
        n = s.scalar(select(func.count()).select_from(EventEnrichment))
        total = s.scalar(select(func.count()).select_from(Event))
    if n == prev:
        stall = stall + 1 if 'stall' in dir() else 1
    else:
        stall = 0
    prev = n
    if n >= total or stall > 12:
        break
    time.sleep(10)
print(f"final: {n}/{total} enriched")
