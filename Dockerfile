# Drupal 11.3 on Railway
FROM drupal:11.3-apache

# Install additional tools FIRST — apt-get can upgrade Apache packages
# and reset mods-enabled, so the MPM fix must come AFTER this step.
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Drush globally
RUN composer require --working-dir=/opt/drupal drush/drush && \
    ln -sf /opt/drupal/vendor/bin/drush /usr/local/bin/drush

# Fix Apache MPM conflict AFTER apt-get (apt upgrades can reset mods-enabled).
# Delete all MPM symlinks then add ONLY prefork — no other MPM can load.
RUN rm -f /etc/apache2/mods-enabled/mpm_*.load \
          /etc/apache2/mods-enabled/mpm_*.conf && \
    ln -sf /etc/apache2/mods-available/mpm_prefork.load \
           /etc/apache2/mods-enabled/mpm_prefork.load && \
    ln -sf /etc/apache2/mods-available/mpm_prefork.conf \
           /etc/apache2/mods-enabled/mpm_prefork.conf && \
    echo "=== MPM fix applied ===" && \
    ls -la /etc/apache2/mods-enabled/mpm_*

# Copy Drupal config
COPY docker/settings.php /opt/drupal/web/sites/default/settings.php
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    mkdir -p /opt/drupal/web/sites/default/files && \
    chown -R www-data:www-data /opt/drupal/web/sites/default/files && \
    chmod 775 /opt/drupal/web/sites/default/files

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
