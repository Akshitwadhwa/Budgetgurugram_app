from __future__ import annotations

import logging
import time

from apscheduler.schedulers.blocking import BlockingScheduler

from core.config import get_settings
from worker.pipeline import run_pipeline

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger(__name__)


def main() -> None:
    settings = get_settings()
    scheduler = BlockingScheduler()
    scheduler.add_job(run_pipeline, "interval", hours=settings.scrape_interval_hours, id="discover")
    log.info("running initial pipeline, then every %s hours", settings.scrape_interval_hours)
    run_pipeline()
    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        log.info("worker stopped")
        time.sleep(0)


if __name__ == "__main__":
    main()
