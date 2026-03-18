# Drupal 11.3 on Railway
# Uses the official Drupal image so Railway doesn't need to compile PHP extensions
FROM drupal:11.3-apache

# Fix Apache MPM conflict: mod_php requires mpm_prefork; disable others
RUN a2dismod mpm_event mpm_worker 2>/dev/null || true && \
    a2enmod mpm_prefork

# Install additional tools needed for entrypoint
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Drush globally
RUN composer require --working-dir=/opt/drupal drush/drush && \
    ln -sf /opt/drupal/vendor/bin/drush /usr/local/bin/drush

# Copy Drupal config
COPY docker/settings.php /opt/drupal/web/sites/default/settings.php
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && \
    # Ensure sites/default/files is writable
    mkdir -p /opt/drupal/web/sites/default/files && \
    chown -R www-data:www-data /opt/drupal/web/sites/default/files && \
    chmod 775 /opt/drupal/web/sites/default/files

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
