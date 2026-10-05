"""Scan worker: long-polls SQS and runs one scan per message."""

import json
import logging
import threading

from django.db import close_old_connections

from . import queue, scanner

log = logging.getLogger("scans.worker")


def run(stop: threading.Event | None = None) -> None:
    log.info("worker started")
    while not (stop and stop.is_set()):
        for message in queue.receive():
            job_id = json.loads(message["Body"])["job_id"]
            close_old_connections()
            try:
                scanner.run(job_id)
            except Exception:
                # Leave the message: SQS redelivers it after the visibility
                # timeout, and the redrive policy moves it to the DLQ eventually.
                log.exception("scan failed", extra={"job_id": job_id})
                continue
            queue.delete(message)
