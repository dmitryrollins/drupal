#!/bin/bash
set -e

echo "=== Drupal Railway Entrypoint ==="

# ── Wait for database ────────────────────────────────────────────────────────
wait_for_db() {
  local retries=30
  local wait=2

  if [ -n "$PGHOST" ]; then
    echo "Waiting for PostgreSQL at $PGHOST:${PGPORT:-5432}..."
    for i in $(seq 1 $retries); do
      if pg_isready -h "$PGHOST" -p "${PGPORT:-5432}" -U "$PGUSER" -d "${PGDATABASE:-drupal}" -q 2>/dev/null; then
        echo "PostgreSQL is ready."
        return 0
      fi
      echo "  Attempt $i/$retries — retrying in ${wait}s..."
      sleep $wait
    done
    echo "ERROR: PostgreSQL did not become ready in time."
    exit 1

  elif [ -n "$MYSQLHOST" ]; then
    echo "Waiting for MySQL at $MYSQLHOST:${MYSQLPORT:-3306}..."
    for i in $(seq 1 $retries); do
      if mysqladmin ping -h "$MYSQLHOST" -P "${MYSQLPORT:-3306}" -u "$MYSQLUSER" -p"$MYSQLPASSWORD" --silent 2>/dev/null; then
        echo "MySQL is ready."
        return 0
      fi
      echo "  Attempt $i/$retries — retrying in ${wait}s..."
      sleep $wait
    done
    echo "ERROR: MySQL did not become ready in time."
    exit 1

  elif [ -n "$DATABASE_URL" ]; then
    echo "DATABASE_URL is set — skipping explicit DB wait (will fail at install if not ready)."
  else
    echo "WARNING: No database environment variables found (PGHOST / MYSQLHOST / DATABASE_URL)."
    echo "         Drupal will not be able to install or run without a database."
  fi
}

wait_for_db

# ── Ensure writable directories ──────────────────────────────────────────────
mkdir -p /opt/drupal/web/sites/default/files
mkdir -p /opt/drupal/private
mkdir -p /opt/drupal/config/sync
chown -R www-data:www-data \
  /opt/drupal/web/sites/default/files \
  /opt/drupal/private \
  /opt/drupal/config/sync

# ── Install Drupal if not already installed ──────────────────────────────────
cd /opt/drupal

echo "Checking if Drupal is already installed..."
if ! drush status --field=drupal-settings-file 2>/dev/null | grep -q "settings.php"; then
  echo "Drupal settings found."
fi

if drush status bootstrap 2>/dev/null | grep -q "Successful"; then
  echo "Drupal is already installed — skipping site install."
else
  echo "Drupal not installed yet — running site install..."

  SITE_NAME="${DRUPAL_SITE_NAME:-TravelNinja Content}"
  ADMIN_USER="${DRUPAL_ADMIN_USER:-admin}"
  ADMIN_PASS="${DRUPAL_ADMIN_PASS:-changeme}"
  ADMIN_EMAIL="${DRUPAL_ADMIN_EMAIL:-admin@example.com}"
  DB_DRIVER="pgsql"
  DB_URL=""

  if [ -n "$DATABASE_URL" ]; then
    DB_URL="$DATABASE_URL"
  elif [ -n "$PGHOST" ]; then
    DB_URL="pgsql://${PGUSER}:${PGPASSWORD}@${PGHOST}:${PGPORT:-5432}/${PGDATABASE:-drupal}"
  elif [ -n "$MYSQLHOST" ]; then
    DB_URL="mysql://${MYSQLUSER}:${MYSQLPASSWORD}@${MYSQLHOST}:${MYSQLPORT:-3306}/${MYSQLDATABASE:-drupal}"
  fi

  if [ -z "$DB_URL" ]; then
    echo "ERROR: Cannot install Drupal — no database URL available."
    exit 1
  fi

  drush site:install standard \
    --db-url="$DB_URL" \
    --site-name="$SITE_NAME" \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --account-mail="$ADMIN_EMAIL" \
    --yes

  echo "Enabling required modules..."
  drush en jsonapi basic_auth serialization --yes

  echo "Creating JSON:API user..."
  API_USER="${DRUPAL_API_USER:-api_user}"
  API_PASS="${DRUPAL_API_PASS:-api_password}"
  drush user:create "$API_USER" --password="$API_PASS" --mail="${API_USER}@example.com" || true
  drush user:role:add administrator "$API_USER" || true

  echo "Drupal install complete!"
  echo "  Admin:    $ADMIN_USER / $ADMIN_PASS"
  echo "  API user: $API_USER / $API_PASS"
fi

# ── Start Apache ─────────────────────────────────────────────────────────────
echo "Starting Apache..."
exec "$@"
