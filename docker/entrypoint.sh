#!/bin/bash
set -e

echo "=== Drupal Railway Entrypoint ==="

# ── Port configuration ───────────────────────────────────────────────────────
# Railway injects $PORT; Apache must listen on it, not hardcoded 80.
PORT="${PORT:-80}"
echo "Configuring Apache to listen on port $PORT..."

sed -i "s/Listen 80$/Listen $PORT/" /etc/apache2/ports.conf
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:$PORT>/" \
    /etc/apache2/sites-enabled/000-default.conf 2>/dev/null || true

# ── Writable directories ─────────────────────────────────────────────────────
mkdir -p \
    /opt/drupal/web/sites/default/files \
    /opt/drupal/private \
    /opt/drupal/config/sync
chown -R www-data:www-data \
    /opt/drupal/web/sites/default/files \
    /opt/drupal/private \
    /opt/drupal/config/sync

# ── Start Apache ─────────────────────────────────────────────────────────────
# Drupal's web installer at /core/install.php handles first-time setup.
# Add a PostgreSQL service in Railway, set the DB env vars, then visit
# your Railway URL to complete the Drupal install wizard.
echo "Starting Apache on port $PORT..."
exec "$@"
