import logging

from django.db import connection
from django.http import JsonResponse
from django.views.decorators.http import require_GET, require_POST

from . import exports, queue
from .models import Member, ScanJob, Subscription

log = logging.getLogger("scans.api")


@require_GET
def healthz(request):
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        log.exception("health check failed")
        return JsonResponse({"status": "error"}, status=503)
    return JsonResponse({"status": "ok"})


@require_POST
def start_scan(request, member_id: int):
    member, _ = Member.objects.get_or_create(id=member_id, defaults={"client": "demo", "external_id": str(member_id)})
    job = ScanJob.objects.create(member=member)
    queue.send_scan(job.id)
    log.info("scan queued", extra={"job_id": job.id, "member_id": member.id})
    return JsonResponse({"job_id": job.id, "status": job.status}, status=202)


@require_GET
def scan_status(request, job_id: int):
    job = ScanJob.objects.filter(id=job_id).first()
    if job is None:
        return JsonResponse({"error": "not found"}, status=404)
    return JsonResponse({"job_id": job.id, "status": job.status})


@require_GET
def subscriptions(request, member_id: int):
    subs = Subscription.objects.filter(member_id=member_id).order_by("merchant")
    return JsonResponse(
        {"subscriptions": [{"merchant": s.merchant, "cadence": s.cadence, "amount": str(s.amount)} for s in subs]}
    )


@require_POST
def export(request, member_id: int):
    subs = Subscription.objects.filter(member_id=member_id).order_by("merchant")
    url = exports.export_subscriptions(member_id, subs)
    log.info("export created", extra={"member_id": member_id})
    return JsonResponse({"url": url}, status=201)
