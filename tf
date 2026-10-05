#!/bin/sh
# Terraform 1.9 in Docker, pointed at LocalStack. Usage: ./tf <dir> <terraform args>
#   ./tf prod/core plan
# With Terraform installed you can use it directly instead:
#   TF_VAR_localstack_url=http://localhost:4566 terraform -chdir=prod/core plan
set -e
dir=$1
shift
root=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$root/.terraform.d/plugin-cache"
network=""
if docker network inspect scan-infra_default >/dev/null 2>&1; then network="--network scan-infra_default"; fi
# shellcheck disable=SC2086
exec docker run --rm -i $network \
  -v "$root:/repo" -w "/repo/$dir" \
  -e TF_VAR_localstack_url=http://localstack:4566 \
  -e TF_PLUGIN_CACHE_DIR=/repo/.terraform.d/plugin-cache \
  -e TF_IN_AUTOMATION=1 \
  hashicorp/terraform:1.9.8 "$@"
