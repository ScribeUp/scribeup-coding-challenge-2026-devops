"""Thin wrapper around the SQS scan queue."""

import json
from functools import lru_cache

import boto3
from django.conf import settings


@lru_cache(maxsize=1)
def _client():
    # Honors AWS_ENDPOINT_URL_SQS, so the same code talks to ElasticMQ locally.
    return boto3.client("sqs", region_name=settings.AWS_REGION)


def send_scan(job_id: int) -> None:
    _client().send_message(QueueUrl=settings.SCAN_QUEUE_URL, MessageBody=json.dumps({"job_id": job_id}))


def receive(wait_seconds: int = 10) -> list[dict]:
    response = _client().receive_message(
        QueueUrl=settings.SCAN_QUEUE_URL,
        MaxNumberOfMessages=1,
        WaitTimeSeconds=wait_seconds,
        VisibilityTimeout=settings.SCAN_VISIBILITY_TIMEOUT_SECONDS,
    )
    return response.get("Messages", [])


def delete(message: dict) -> None:
    _client().delete_message(QueueUrl=settings.SCAN_QUEUE_URL, ReceiptHandle=message["ReceiptHandle"])


def reset_client() -> None:
    _client.cache_clear()
