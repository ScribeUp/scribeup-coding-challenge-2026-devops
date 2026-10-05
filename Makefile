TF := ./tf

.PHONY: up down plan validate test pull logs queue

# Start "production": LocalStack + Postgres, apply prod/core to it, then the API, worker and traffic.
up:
	docker compose up -d --wait db localstack
	$(TF) prod/core init -input=false >/dev/null
	$(TF) prod/core apply -input=false -auto-approve
	docker compose up -d --build --wait web
	docker compose up -d worker traffic
	sh scripts/seed.sh
	@echo "Production is up. API on http://localhost:8000. Try: make queue, make plan"

# LocalStack keeps nothing after it stops, so the Terraform state goes too.
down:
	docker compose down -v
	rm -f prod/core/terraform.tfstate prod/core/terraform.tfstate.backup prod/core/tfplan prod/core/plan.json

# Plan prod/core against "production" and save the JSON plan. Runs scripts/plan_guard on it once it exists.
plan:
	$(TF) prod/core plan -input=false -out=tfplan
	$(TF) prod/core show -json tfplan > prod/core/plan.json
	@if [ -x scripts/plan_guard ]; then scripts/plan_guard prod/core/plan.json; else echo "(no scripts/plan_guard yet)"; fi

validate:
	$(TF) . fmt -check -recursive prod
	@for d in prod/core prod/database; do \
		echo "== $$d"; $(TF) $$d init -backend=false -input=false >/dev/null && $(TF) $$d validate || exit 1; \
	done
	@if command -v actionlint >/dev/null; then actionlint && echo "actionlint: OK"; else echo "actionlint not installed, skipping"; fi

test:
	docker compose run --rm --build web sh -c "pip install -q -r requirements-dev.txt && python manage.py test scans --noinput"

# Download the images ahead of time.
pull:
	docker compose pull db localstack
	docker pull hashicorp/terraform:1.9.8
	docker compose build

logs:
	docker compose logs -f web worker

queue:
	@./aws sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/scans-production \
		--attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible
