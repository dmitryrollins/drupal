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

# ── Runtime MPM safety net ───────────────────────────────────────────────────
# Belt-and-suspenders: wipe any non-prefork MPM that may have crept back in
# (apt-get can reset mods-enabled during builds).  Runs every container start.
echo "Ensuring only mpm_prefork is loaded..."
rm -f /etc/apache2/mods-enabled/mpm_event.load \
      /etc/apache2/mods-enabled/mpm_event.conf \
      /etc/apache2/mods-enabled/mpm_worker.load \
      /etc/apache2/mods-enabled/mpm_worker.conf
ln -sf /etc/apache2/mods-available/mpm_prefork.load \
       /etc/apache2/mods-enabled/mpm_prefork.load 2>/dev/null || true
ln -sf /etc/apache2/mods-available/mpm_prefork.conf \
       /etc/apache2/mods-enabled/mpm_prefork.conf 2>/dev/null || true
echo "Active MPM modules:"
ls /etc/apache2/mods-enabled/mpm_* 2>/dev/null || echo "  none listed (may be compiled-in)"

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
