#!/bin/bash
set -e

DB_PATH="${DATABASE_PATH:-/mnt/data/ohio_elixir.db}"
mkdir -p "$(dirname "$DB_PATH")"

# Restore from backup if DB doesn't exist
if [ ! -f "$DB_PATH" ]; then
    echo "Restoring database from Litestream backup..."
    litestream restore -if-replica-exists -o "$DB_PATH" "$DB_PATH" || echo "No backup found, starting fresh."
fi

# Ensure WAL mode
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" "PRAGMA journal_mode=WAL;" || true
fi

# Start app with Litestream replication
# Use /app/bin/server which sets PHX_SERVER=true automatically
exec litestream replicate -exec "/app/bin/server"
