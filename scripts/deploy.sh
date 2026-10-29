#!/usr/bin/env bash
# One-command deploy: checks prerequisites, runs Terraform, waits for the
# service to become healthy, then runs scripts/verify.sh against it.
# Usage: scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/terraform"

fail() { echo "ERROR: $*" >&2; exit 1; }

# 1. Prerequisites
for tool in terraform aws curl; do
  command -v "$tool" >/dev/null 2>&1 || fail "'$tool' is not installed (see README > Prerequisites)"
done
aws sts get-caller-identity >/dev/null 2>&1 \
  || fail "AWS credentials not working. Run 'aws configure' first."

# 2. Restrict SSH to this machine's public IP (written once, gitignored)
if [ ! -f "$TF_DIR/terraform.tfvars" ]; then
  my_ip="$(curl -fsS --max-time 5 https://checkip.amazonaws.com | tr -d '[:space:]')" \
    || fail "could not detect your public IP; create terraform/terraform.tfvars by hand"
  echo "admin_cidr = \"$my_ip/32\"" > "$TF_DIR/terraform.tfvars"
  echo "SSH will be allowed only from $my_ip/32 (saved in terraform/terraform.tfvars)"
fi

# 3. Provision
terraform -chdir="$TF_DIR" init -input=false
terraform -chdir="$TF_DIR" apply -input=false

url="$(terraform -chdir="$TF_DIR" output -raw service_url)"

# 4. Wait for first boot (cloud-init) to finish, max ~5 minutes
echo "Waiting for $url to become healthy..."
for i in $(seq 1 30); do
  if curl -fsS --max-time 5 "${url}health" >/dev/null 2>&1; then
    echo "Healthy after ~$((i * 10))s"
    exec bash "$ROOT/scripts/verify.sh" "$url"
  fi
  sleep 10
done

fail "service did not become healthy within 5 minutes. See README > Troubleshooting."
