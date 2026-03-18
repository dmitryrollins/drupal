#!/bin/bash
set -e

echo "=== Drupal Railway Entrypoint ==="

# ── Port configuration ───────────────────────────────────────────────────────
# Railway injects $PORT. We overwrite ports.conf directly instead of using
# sed (sed can fail silently if the pattern doesn't match exactly).
PORT="${PORT:-80}"
echo "Configuring Apache on port $PORT..."

# Overwrite ports.conf — only listen on $PORT
cat > /etc/apache2/ports.conf <<EOF
Listen ${PORT}
EOF

# Update VirtualHost port in default site if it exists
for conf in /etc/apache2/sites-enabled/*.conf; do
    [ -f "$conf" ] && sed -i "s/<VirtualHost \*:[0-9]*>/<VirtualHost *:${PORT}>/" "$conf"
done

# ── Writable directories ─────────────────────────────────────────────────────
mkdir -p \
    /opt/drupal/web/sites/default/files \
    /opt/drupal/private \
    /opt/drupal/config/sync
chown -R www-data:www-data \
    /opt/drupal/web/sites/default/files \
    /opt/drupal/private \
    /opt/drupal/config/sync

echo "Starting Apache on port $PORT..."
exec "$@"
