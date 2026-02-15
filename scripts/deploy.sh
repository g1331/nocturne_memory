#!/usr/bin/env sh
set -eu

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1"
    exit 1
  fi
}

get_service_container_id() {
  service_name="$1"
  id="$(docker compose ps -q "$service_name" | tr -d '\r' | tr -d '\n')"
  if [ -z "$id" ]; then
    echo "Container for service '$service_name' was not created."
    exit 1
  fi
  printf '%s' "$id"
}

wait_service_state() {
  service_name="$1"
  expected_state="$2"
  timeout_seconds="${3:-120}"
  elapsed=0
  id="$(get_service_container_id "$service_name")"

  while [ "$elapsed" -lt "$timeout_seconds" ]; do
    state="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$id" | tr -d '\r' | tr -d '\n')"

    if [ "$state" = "$expected_state" ]; then
      echo "$service_name status: $state"
      return 0
    fi

    if [ "$state" = "exited" ] || [ "$state" = "dead" ]; then
      echo "Service '$service_name' is not running (state: $state)."
      return 1
    fi

    sleep 2
    elapsed=$((elapsed + 2))
  done

  echo "Timed out waiting for '$service_name' to reach state '$expected_state'."
  return 1
}

require_command docker

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin is not available."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running."
  exit 1
fi

echo "Starting containers (build + up)..."
docker compose up -d --build

if ! wait_service_state backend healthy 180 || \
   ! wait_service_state web running 120 || \
   ! wait_service_state mcp-sse running 120; then
  echo "Deployment failed. Showing recent logs..."
  docker compose logs --no-color --tail=200 backend web mcp-sse
  exit 1
fi

echo ""
echo "Deployment completed."
echo "Web UI:     http://localhost:18080"
echo "MCP SSE:    http://localhost:18081/sse"
echo "MCP HTTP:   http://localhost:18081/mcp"
