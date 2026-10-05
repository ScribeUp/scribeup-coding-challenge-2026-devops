import json
import os
from unittest import mock

import boto3
from django.test import TestCase, override_settings
from moto import mock_aws

from scans import exports, queue, scanner
from scans.models import ScanJob


@mock_aws
class ScanApiTests(TestCase):
    def setUp(self):
        # Use moto's in-memory SQS even if a local endpoint (ElasticMQ) is configured.
        self.env = mock.patch.dict(os.environ, {"AWS_ACCESS_KEY_ID": "test", "AWS_SECRET_ACCESS_KEY": "test"})
        self.env.start()
        for var in ("AWS_ENDPOINT_URL", "AWS_ENDPOINT_URL_SQS", "AWS_ENDPOINT_URL_S3"):
            os.environ.pop(var, None)
        queue.reset_client()
        exports.reset_client()
        self.sqs = boto3.client("sqs", region_name="us-east-1")
        self.queue_url = self.sqs.create_queue(QueueName="scans-test")["QueueUrl"]
        self.s3 = boto3.client("s3", region_name="us-east-1")
        self.s3.create_bucket(Bucket="exports-test")
        self.settings_override = override_settings(
            SCAN_QUEUE_URL=self.queue_url,
            SCAN_SIMULATED_SECONDS=0,
            EXPORTS_BUCKET="exports-test",
            EXPORTS_BASE_URL="https://exports-test.s3.amazonaws.com",
        )
        self.settings_override.enable()

    def tearDown(self):
        self.settings_override.disable()
        self.env.stop()
        queue.reset_client()
        exports.reset_client()

    def test_healthz(self):
        self.assertEqual(self.client.get("/healthz").json(), {"status": "ok"})

    def test_start_scan_queues_a_message(self):
        response = self.client.post("/members/42/scans")
        self.assertEqual(response.status_code, 202)
        messages = self.sqs.receive_message(QueueUrl=self.queue_url).get("Messages", [])
        self.assertEqual(json.loads(messages[0]["Body"]), {"job_id": response.json()["job_id"]})

    def test_scan_saves_subscriptions(self):
        job_id = self.client.post("/members/7/scans").json()["job_id"]
        scanner.run(job_id)
        self.assertEqual(ScanJob.objects.get(id=job_id).status, ScanJob.Status.SUCCEEDED)
        self.assertEqual(len(self.client.get("/members/7/subscriptions").json()["subscriptions"]), 4)

    def test_duplicate_delivery_is_ignored(self):
        job_id = self.client.post("/members/8/scans").json()["job_id"]
        scanner.run(job_id)
        scanner.run(job_id)
        self.assertEqual(len(self.client.get("/members/8/subscriptions").json()["subscriptions"]), 4)

    def test_export_uploads_a_csv_and_returns_its_link(self):
        job_id = self.client.post("/members/9/scans").json()["job_id"]
        scanner.run(job_id)
        response = self.client.post("/members/9/exports")
        self.assertEqual(response.status_code, 201)
        url = response.json()["url"]
        self.assertTrue(url.startswith("https://exports-test.s3.amazonaws.com/exports/9/"))
        key = url.split(".com/", 1)[1]
        body = self.s3.get_object(Bucket="exports-test", Key=key)["Body"].read().decode()
        self.assertEqual(body.splitlines()[0], "merchant,cadence,amount")
