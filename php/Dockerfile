FROM php:8.3-fpm-alpine

RUN apk add --no-cache \
    postgresql-dev \
    libzip-dev \
    zip \
    redis \
    && docker-php-ext-install pdo_pgsql zip opcache

# Redis extension
RUN pecl install redis && docker-php-ext-enable redis

COPY <<EOF /usr/local/etc/php/conf.d/custom.ini
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 120

opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=100000

session.save_handler = redis
session.save_path = "tcp://redis:6379"
EOF

WORKDIR /var/www/html
