from django.db import models


class Member(models.Model):
    client = models.CharField(max_length=50)
    external_id = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["client", "external_id"], name="uniq_member_per_client")]


class ScanJob(models.Model):
    class Status(models.TextChoices):
        QUEUED = "QUEUED"
        RUNNING = "RUNNING"
        SUCCEEDED = "SUCCEEDED"
        FAILED = "FAILED"

    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="scan_jobs")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.QUEUED)
    error = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)


class Subscription(models.Model):
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name="subscriptions")
    merchant = models.CharField(max_length=200)
    cadence = models.CharField(max_length=20)
    amount = models.DecimalField(max_digits=12, decimal_places=2)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["member", "merchant"], name="uniq_subscription_per_member")]
