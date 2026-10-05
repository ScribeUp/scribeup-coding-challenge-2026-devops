#!/bin/sh
# Gives "production" some history: the app secret's value, member exports already
# emailed out, worker logs, and a backlog from this morning's client launch.
set -e
cd "$(dirname "$0")/.."

./aws secretsmanager put-secret-value --secret-id scan/production/app \
  --secret-string '{"DATABASE_URL":"postgres://scan_admin:not-the-real-one@scan-production.c8x2k1.us-east-1.rds.amazonaws.com:5432/scan","SECRET_KEY":"not-the-real-one"}' >/dev/null

for member in 101 102 103 104 105; do
  curl -sf -X POST "localhost:8000/members/$member/scans" >/dev/null
done
sleep 8
for member in 101 102 103 104 105; do
  curl -sf -X POST "localhost:8000/members/$member/exports" >/dev/null
done

./aws logs create-log-stream --log-group-name /scan/production/worker --log-stream-name worker-1 2>/dev/null || true
./aws logs put-log-events --log-group-name /scan/production/worker --log-stream-name worker-1 \
  --log-events "[{\"timestamp\": $(($(date +%s) * 1000)), \"message\": \"scan finished job_id=1\"}]" >/dev/null

# The launch backlog.
i=0
while [ $i -lt 300 ]; do
  curl -sf -X POST "localhost:8000/members/$((2000 + i))/scans" >/dev/null
  i=$((i + 1))
done
echo "Seeded: app secret, 5 member exports, worker logs, and 300 queued scans."
