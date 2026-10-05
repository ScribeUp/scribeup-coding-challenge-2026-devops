"""Runs a scan. In this exercise the bank and vendor calls are simulated."""

import logging
import random
import time
from decimal import Decimal

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import Member, ScanJob, Subscription

log = logging.getLogger("scans.scanner")

CATALOG = [
    ("Netflix", "monthly", "15.49"),
    ("Spotify", "monthly", "11.99"),
    ("Hulu", "monthly", "7.99"),
    ("Verizon Wireless", "monthly", "85.00"),
    ("New York Times", "weekly", "4.00"),
    ("Planet Fitness", "monthly", "24.99"),
    ("ChatGPT", "monthly", "20.00"),
]


def run(job_id: int) -> None:
    job = ScanJob.objects.select_related("member").get(id=job_id)
    if job.status == ScanJob.Status.SUCCEEDED:
        log.info("scan already finished, ignoring duplicate delivery", extra={"job_id": job_id})
        return
    ScanJob.objects.filter(id=job_id).update(status=ScanJob.Status.RUNNING, started_at=timezone.now())
    started = time.monotonic()

    # Stand-in for fetching transactions from the bank and enriching them.
    time.sleep(settings.SCAN_SIMULATED_SECONDS * random.uniform(0.5, 1.5))
    found = random.Random(job.member_id).sample(CATALOG, 4)

    with transaction.atomic():
        Member.objects.select_for_update().get(id=job.member_id)
        Subscription.objects.filter(member_id=job.member_id).delete()
        Subscription.objects.bulk_create(
            Subscription(member_id=job.member_id, merchant=m, cadence=c, amount=Decimal(a)) for m, c, a in found
        )
    ScanJob.objects.filter(id=job_id).update(status=ScanJob.Status.SUCCEEDED, finished_at=timezone.now())
    log.info(
        "scan finished",
        extra={"job_id": job_id, "member_id": job.member_id, "subscriptions": len(found), "duration_ms": round((time.monotonic() - started) * 1000)},
    )
