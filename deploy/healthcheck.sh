#!/usr/bin/env bash

set -uo pipefail

URL="${HEALTH_URL:-http://127.0.0.1/health}"
SERVICE="${SERVICE_NAME:-hello.service}"

healthy() {
  curl -fsS --max-time 5 "$URL" >/dev/null 2>&1
}

# Try twice before acting, so one slow response does not cause a restart.
if healthy || { sleep 3; healthy; }; then
  exit 0
fi

logger -t hello-healthcheck -p user.warning "FAIL: $URL not healthy, restarting $SERVICE"
systemctl restart "$SERVICE"
sleep 5

if healthy; then
  logger -t hello-healthcheck "RECOVERED: $SERVICE healthy after restart"
  exit 0
fi

logger -t hello-healthcheck -p user.err "STILL DOWN: $SERVICE unhealthy after restart, manual action needed"
exit 1
