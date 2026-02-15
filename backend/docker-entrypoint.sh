#!/bin/sh
set -eu

DB_URL="${DATABASE_URL:-}"
if [ -z "$DB_URL" ]; then
  echo "DATABASE_URL is required."
  exit 1
fi

case "$DB_URL" in
  sqlite+aiosqlite:///*)
    DB_PATH="${DB_URL#sqlite+aiosqlite:///}"
    ;;
  *)
    echo "Unsupported DATABASE_URL for container entrypoint: $DB_URL"
    exit 1
    ;;
esac

DB_DIR="$(dirname "$DB_PATH")"
mkdir -p "$DB_DIR"

if [ ! -f "$DB_PATH" ] && [ -f /app/demo.db ]; then
  cp /app/demo.db "$DB_PATH"
  echo "Seeded initial SQLite database from /app/demo.db to $DB_PATH"
fi

if [ "$#" -gt 0 ]; then
  exec "$@"
fi

exec uvicorn main:app --host 0.0.0.0 --port 8000
