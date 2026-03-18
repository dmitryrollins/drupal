<?php

/**
 * Drupal settings for Railway deployment.
 * Reads database and other config from environment variables.
 */

// ── Database ──────────────────────────────────────────────────────────────────
// Railway PostgreSQL (preferred): PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD
// Railway MySQL fallback:         MYSQLHOST, MYSQLPORT, MYSQLDATABASE, MYSQLUSER, MYSQLPASSWORD
// Or a single DATABASE_URL (postgres://user:pass@host:port/dbname)

if (!empty($_ENV['DATABASE_URL'])) {
  $url = parse_url($_ENV['DATABASE_URL']);
  $driver = strpos($url['scheme'], 'mysql') !== false ? 'mysql' : 'pgsql';
  $databases['default']['default'] = [
    'driver'   => $driver,
    'host'     => $url['host'],
    'port'     => $url['port'] ?? ($driver === 'mysql' ? 3306 : 5432),
    'database' => ltrim($url['path'], '/'),
    'username' => $url['user'],
    'password' => $url['pass'] ?? '',
    'prefix'   => '',
    'namespace' => $driver === 'mysql'
      ? 'Drupal\\mysql\\Driver\\Database\\mysql'
      : 'Drupal\\pgsql\\Driver\\Database\\pgsql',
    'autoload'  => $driver === 'mysql'
      ? 'core/modules/mysql/src/Driver/Database/mysql/'
      : 'core/modules/pgsql/src/Driver/Database/pgsql/',
  ];
} elseif (!empty($_ENV['PGHOST'])) {
  $databases['default']['default'] = [
    'driver'    => 'pgsql',
    'host'      => $_ENV['PGHOST'],
    'port'      => $_ENV['PGPORT'] ?? 5432,
    'database'  => $_ENV['PGDATABASE'] ?? 'drupal',
    'username'  => $_ENV['PGUSER'],
    'password'  => $_ENV['PGPASSWORD'] ?? '',
    'prefix'    => '',
    'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
    'autoload'  => 'core/modules/pgsql/src/Driver/Database/pgsql/',
  ];
} elseif (!empty($_ENV['MYSQLHOST'])) {
  $databases['default']['default'] = [
    'driver'    => 'mysql',
    'host'      => $_ENV['MYSQLHOST'],
    'port'      => $_ENV['MYSQLPORT'] ?? 3306,
    'database'  => $_ENV['MYSQLDATABASE'] ?? 'drupal',
    'username'  => $_ENV['MYSQLUSER'],
    'password'  => $_ENV['MYSQLPASSWORD'] ?? '',
    'prefix'    => '',
    'namespace' => 'Drupal\\mysql\\Driver\\Database\\mysql',
    'autoload'  => 'core/modules/mysql/src/Driver/Database/mysql/',
  ];
}

// ── Trusted host patterns ────────────────────────────────────────────────────
// Railway public domain and any custom domain
$settings['trusted_host_patterns'] = [
  '^.+\.railway\.app$',
  '^.+\.up\.railway\.app$',
  '^localhost$',
  '^127\.0\.0\.1$',
];
// Add custom domain from env var if set: DRUPAL_TRUSTED_HOST=dev-travelninja-content.pantheonsite.io
if (!empty($_ENV['DRUPAL_TRUSTED_HOST'])) {
  $escaped = preg_quote($_ENV['DRUPAL_TRUSTED_HOST'], '/');
  $settings['trusted_host_patterns'][] = '^' . $escaped . '$';
}

// ── Hash salt ────────────────────────────────────────────────────────────────
// Generate a random one if not set; must be stable across restarts in production.
$settings['hash_salt'] = $_ENV['DRUPAL_HASH_SALT'] ?? 'change-this-to-a-long-random-string-in-railway-env';

// ── File paths ───────────────────────────────────────────────────────────────
$settings['file_public_path']  = 'sites/default/files';
$settings['file_private_path'] = '/opt/drupal/private';
$settings['file_temp_path']    = '/tmp';

// ── Config sync directory ────────────────────────────────────────────────────
$settings['config_sync_directory'] = '../config/sync';

// ── Performance ──────────────────────────────────────────────────────────────
// Disable Drupal's page cache when running behind Railway's proxy
if (!empty($_ENV['RAILWAY_ENVIRONMENT'])) {
  $settings['reverse_proxy'] = TRUE;
  $settings['reverse_proxy_addresses'] = ['127.0.0.1'];
}

// ── JSON:API ─────────────────────────────────────────────────────────────────
// Allow read-only JSON:API for the TravelNinja sync pipeline
$config['jsonapi.settings']['read_only'] = FALSE;
