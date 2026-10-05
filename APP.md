# The scan service: what's running in production

When a bank member turns on ScribeUp inside their banking app, the client calls our API to start a **scan**: we pull the member's transaction history, find their recurring subscriptions, and save them. The bank and vendor calls are simulated in this repo; everything else behaves like production.

## Processes

| Process | Command | Notes |
|---|---|---|
| **web** | `gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 3` | Health check: `GET /healthz` (checks the database, returns 503 if it can't reach it) |
| **worker** | `python manage.py run_worker` | No port. Long-polls SQS and runs one scan at a time per process |
| migrations | `python manage.py migrate --noinput` | Run once per deploy, before the new code takes traffic |

Both use the same image (`app/Dockerfile`).

## API

| Endpoint | What it does |
|---|---|
| `POST /members/{id}/scans` | Queue a scan; returns `202 {"job_id": ...}` |
| `GET /scans/{job_id}` | Scan status: `QUEUED`, `RUNNING`, `SUCCEEDED`, `FAILED` |
| `GET /members/{id}/subscriptions` | The member's subscriptions |
| `POST /members/{id}/exports` | Writes the member's subscriptions to a CSV in the exports bucket and returns the link we email them |
| `GET /healthz` | Health check |

## Configuration (environment variables)

| Variable | Secret? | Notes |
|---|---|---|
| `SECRET_KEY`, `DATABASE_URL` | yes | Both come from the Secrets Manager secret `scan/production/app`. `DATABASE_URL` logs in as the RDS master user, `scan_admin` |
| `DB_SSLMODE` | no | Use `require` in production |
| `SCAN_QUEUE_URL` | no | `https://sqs.us-east-1.amazonaws.com/418295617702/scans-production` |
| `EXPORTS_BUCKET` | no | `scan-member-exports-production` |
| `AWS_REGION` | no | Default `us-east-1` |
| `SCAN_VISIBILITY_TIMEOUT_SECONDS` | no | Default 300. Most scans take 2–10 seconds; the largest accounts take up to 4 minutes |
| `DD_ENV`, `DD_SERVICE`, `DD_VERSION` | no | Datadog tags: `DD_ENV=prod`, `DD_SERVICE=scan-api` (web) or `scan-worker` (worker), `DD_VERSION=<git sha>` |
| `LOG_LEVEL` | no | Logs are JSON on stdout |

## Where it runs

Elastic Beanstalk: a web environment and a worker environment, in one AWS account (`418295617702`), `us-east-1`. RDS Postgres, SQS, S3, Secrets Manager, CloudWatch Logs. Datadog for APM, logs and monitors; PagerDuty for on-call.

Terraform covers part of it, applied from a laptop with local state:

| Directory | What it manages | Not in Terraform |
|---|---|---|
| `prod/core` | The scan queue, the exports bucket, the worker's IAM role, the worker log group, the app secret | The Beanstalk environments, the web role, the VPC |
| `prod/database` | RDS Postgres and its security group | |

## IAM

| Role | Used by | Managed by | Permissions |
|---|---|---|---|
| `scan-worker-production` | Worker instances, through the instance profile `scan-worker-production` (the Beanstalk worker environment points at the profile by name) | Terraform (`prod/core`) | `*` on `*` |
| `scan-web-production` | Web instances, through the instance profile `scan-web-production` | The Beanstalk console | `sqs:SendMessage` on the scan queue; `secretsmanager:GetSecretValue` on `scan/production/app`; `s3:PutObject` and `s3:PutObjectAcl` on the exports bucket |

## Data

- Postgres is about 200 GB, growing about 10 GB a month: members' transaction history and subscriptions (financial PII). It has no backups today.
- The data team runs reporting queries from their laptops, straight against the production database.
- We never store card numbers. Card changes go through the card processor's API using tokens.
- **Exports:** the API uploads each CSV with `ACL=public-read` and emails the member a plain link to the object (`https://scan-member-exports-production.s3.amazonaws.com/exports/<member>/<uuid>.csv`). Links are meant to last 7 days; nothing deletes the files today.
- **Worker logs** in CloudWatch are our record of which members' data each scan touched. They're part of our SOC 2 evidence.

## Load

- About 40 clients (banks, credit unions, fintechs). API traffic peaks around 30 requests/second.
- About 20,000 scans on a normal day. The queue usually holds a few hundred to a few thousand messages during the day.
- **Acme Credit Union launches Thursday at 9am ET:** about 40,000 members over two days.

## Compliance

Vanta watches our AWS configuration for SOC 2 Type II; the observation period runs until March. Our PCI DSS assessment starts in January.

## Locally

`make up` runs all of this on your laptop: LocalStack plays AWS and `prod/core` is applied to it, so `make plan` shows what a change would do to "production". LocalStack doesn't run RDS (so `prod/database` is only validated), and it doesn't enforce IAM, KMS key policies or S3 access settings: an apply that would fail or break something in AWS can look fine here.
