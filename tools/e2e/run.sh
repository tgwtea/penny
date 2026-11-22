#!/usr/bin/env bash
# End-to-end tests: the web client in headless Chrome against the real API,
# a fresh database and the Firebase Auth emulator. Run with `task test:e2e`
# while `task dev` is up. Nothing is faked.
#
# The script creates its own database, builds and starts the API on ports
# of its own (so a `task run:api` on 8080 is left alone), runs every
# apps/client/integration_test/*_test.dart, then stops everything and drops
# the database, also when a test fails.
#
# Needs: Docker (task dev), Go, Flutter, Chrome or Chromium and a matching
# chromedriver on PATH. On Linux with Chromium, set CHROME_EXECUTABLE.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
api_port="${PENNY_E2E_API_PORT:-18080}"
admin_port="${PENNY_E2E_ADMIN_PORT:-19090}"
web_port="${PENNY_E2E_WEB_PORT:-15173}"
driver_port="${PENNY_E2E_DRIVER_PORT:-4444}"
pg_port="${PENNY_POSTGRES_PORT:-5432}"
db="penny_e2e_$(date +%s)"
work="$(mktemp -d)"
pids=()

psql_admin() {
  docker compose --project-directory "$root" exec -T postgres \
    psql --username=penny --dbname=penny --quiet --no-psqlrc "$@"
}

cleanup() {
  status=$?
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  psql_admin -c "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" >/dev/null 2>&1 || true
  if [ "$status" -ne 0 ]; then
    echo "e2e: failed; API log follows" >&2
    cat "$work/api.log" 2>/dev/null >&2 || true
  fi
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT

for tool in docker go flutter chromedriver; do
  command -v "$tool" >/dev/null || { echo "e2e: $tool is not on PATH" >&2; exit 1; }
done

echo "e2e: database $db"
psql_admin -c "CREATE DATABASE \"$db\"" >/dev/null
export PENNY_DATABASE_URL="postgres://penny:penny@localhost:${pg_port}/${db}?sslmode=disable"
export PENNY_LOG_FORMAT=text

echo "e2e: building the API"
(cd "$root/services/api" && go build -o "$work/" ./cmd/api ./cmd/migrate)
"$work/migrate" >/dev/null

PENNY_HTTP_ADDR=":${api_port}" \
PENNY_ADMIN_ADDR=":${admin_port}" \
PENNY_CORS_ORIGINS="http://localhost:${web_port}" \
PENNY_FIREBASE_PROJECT_ID=demo-penny \
PENNY_FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
PENNY_UNSUBSCRIBE_SECRET=end-to-end-unsubscribe-secret-not-for-production \
PENNY_APP_URL="http://localhost:${web_port}" \
  "$work/api" >"$work/api.log" 2>&1 &
pids+=($!)

for _ in $(seq 1 50); do
  curl --silent --fail "http://localhost:${api_port}/readyz" >/dev/null && break
  sleep 0.2
done
curl --silent --fail "http://localhost:${api_port}/readyz" >/dev/null \
  || { echo "e2e: the API did not become ready" >&2; exit 1; }

if ! curl --silent "http://localhost:${driver_port}/status" >/dev/null; then
  chromedriver --port="$driver_port" >"$work/chromedriver.log" 2>&1 &
  pids+=($!)
  sleep 1
fi

cd "$root/apps/client"
for target in integration_test/*_test.dart; do
  echo "e2e: $target"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    -d web-server --web-port="$web_port" --browser-name=chrome --headless \
    --dart-define=PENNY_BACKEND=http \
    --dart-define=PENNY_API_URL="http://localhost:${api_port}" \
    --driver-port="$driver_port"
done
echo "e2e: all passed"
