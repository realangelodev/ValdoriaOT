#!/usr/bin/env bash
# Waits for the database, creates the tables on first start, then runs the game server.
set -euo pipefail
cd /srv

mysql_cmd() {
  mysql --host="$MYSQL_HOST" --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" "$MYSQL_DATABASE" "$@"
}

echo ">> Waiting for the database at ${MYSQL_HOST}..."
for _ in $(seq 1 60); do
  if mysql_cmd -e 'SELECT 1' >/dev/null 2>&1; then break; fi
  sleep 2
done
mysql_cmd -e 'SELECT 1' >/dev/null

if ! mysql_cmd -N -e "SHOW TABLES LIKE 'players'" | grep -q players; then
  echo ">> First start: creating the database tables"
  mysql_cmd < /srv/schema.sql
fi

exec tfs
