#!/bin/bash
set -e

until mysqladmin ping -h mariadb -P 3306 -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; do
  sleep 1
done

if [ ! -f /var/www/html/wp-config.php ]; then

  wp core download --allow-root --path=/var/www/html --force

  wp config create \
    --allow-root \
    --path=/var/www/html \
    --dbname="${MYSQL_DATABASE}" \
    --dbuser="${MYSQL_USER}" \
    --dbpass="${MYSQL_PASSWORD}" \
    --dbhost=mariadb:3306

  wp core install \
    --allow-root \
    --path=/var/www/html \
    --url="https://${DOMAIN}" \
    --title="Inception" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email

  wp user create \
    --allow-root \
    --path=/var/www/html \
    "${WP_USER}" "${WP_USER_EMAIL}" \
    --role=author \
    --user_pass="${WP_USER_PASSWORD}"
fi

exec php-fpm8.2 -F
