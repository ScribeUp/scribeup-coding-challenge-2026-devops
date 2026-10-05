"""Member CSV exports. Members get a link to their file by email."""

import csv
import io
import uuid
from functools import lru_cache

import boto3
from botocore.config import Config
from django.conf import settings


@lru_cache(maxsize=1)
def _client():
    # Honors AWS_ENDPOINT_URL_S3, so the same code talks to LocalStack locally.
    return boto3.client(
        "s3", region_name=settings.AWS_REGION, config=Config(s3={"addressing_style": settings.S3_ADDRESSING_STYLE})
    )


def export_subscriptions(member_id: int, subscriptions) -> str:
    """Upload the member's subscriptions as a CSV and return the link we email them."""
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["merchant", "cadence", "amount"])
    for s in subscriptions:
        writer.writerow([s.merchant, s.cadence, s.amount])
    key = f"exports/{member_id}/{uuid.uuid4()}.csv"
    _client().put_object(
        Bucket=settings.EXPORTS_BUCKET,
        Key=key,
        Body=out.getvalue().encode(),
        ContentType="text/csv",
        ACL="public-read",
    )
    return f"{settings.EXPORTS_BASE_URL.rstrip('/')}/{key}"


def reset_client() -> None:
    _client.cache_clear()
