#!/usr/bin/env bash
# Runs MyAAC's own web installer from inside the container, step by step, exactly as if
# someone clicked through http://localhost/install. Afterwards it removes itself from the path:
# MyAAC writes install/install.lock and this script is not run again.
set -euo pipefail

SITE=/var/www/html
URL="http://127.0.0.1/install/"
JAR=$(mktemp)
log() { echo "[myaac-install] $*"; }
step() { curl -fsS -b "$JAR" -c "$JAR" "$@"; }

# The installer only answers to addresses listed in ip.txt.
echo "127.0.0.1" > "$SITE/install/ip.txt"
chown www-data:www-data "$SITE/install/ip.txt"

log "Waiting for Apache..."
until curl -fs -o /dev/null "$URL"; do sleep 1; done

# MyAAC adds its tables to the game server's database, so wait until the server has created it.
log "Waiting for the game server to create its database tables..."
until php -r '
  $db = new PDO("mysql:host=db;dbname=" . getenv("MYSQL_DATABASE"), getenv("MYSQL_USER"), getenv("MYSQL_PASSWORD"));
  $db->query("SELECT 1 FROM accounts LIMIT 1");' >/dev/null 2>&1; do
  sleep 3
done

fail_on_error() {
  if grep -qiE 'alert-danger|class="error"|Fatal error' "$1"; then
    log "The installer reported a problem during $2:"
    sed -e 's/<[^>]*>/ /g' "$1" | tr -s ' \n' | grep -iE 'error|fail|please|must' | head -5
    exit 1
  fi
}

OUT=$(mktemp)
step "$URL?step=welcome" -o /dev/null

log "Saving the site configuration..."
step "$URL?step=database" -o "$OUT" \
  --data-urlencode "vars[site_url]=${SITE_URL:-http://localhost}" \
  --data-urlencode "vars[server_path]=/srv/server/" \
  --data-urlencode "vars[date_timezone]=${TZ:-UTC}" \
  --data-urlencode "vars[client]=1098" \
  --data-urlencode "vars[usage]=0"
fail_on_error "$OUT" "configuration"

log "Creating the website tables..."
step "${URL}tools/5-database.php" -o "$OUT"
fail_on_error "$OUT" "database setup"

log "Creating the admin account '${ADMIN_ACCOUNT}' and character '${ADMIN_CHARACTER}'..."
step "$URL?step=finish" -o "$OUT" \
  --data-urlencode "vars[account]=${ADMIN_ACCOUNT}" \
  --data-urlencode "vars[email]=${ADMIN_EMAIL}" \
  --data-urlencode "vars[password]=${ADMIN_PASSWORD}" \
  --data-urlencode "vars[password_confirm]=${ADMIN_PASSWORD}" \
  --data-urlencode "vars[player_name]=${ADMIN_CHARACTER}"
fail_on_error "$OUT" "admin account creation"

step "${URL}tools/7-finish.php" -o "$OUT"
fail_on_error "$OUT" "the final step"

rm -f "$JAR" "$OUT"
log "Done. The website is ready at ${SITE_URL:-http://localhost}"
