ARG PHP_VERSION=
FROM davidalger/php:${PHP_VERSION}-fpm as build

ARG COMPOSER_AUTH
ARG MAGENTO_VERSION
ARG MAGENTO_EDITION

COPY composer-cache /root/.composer/cache
COPY php.d/*.ini /etc/php.d/

RUN composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-${MAGENTO_EDITION}-edition /var/www/html ${MAGENTO_VERSION}

WORKDIR /var/www/html
COPY config.php app/etc/config.php
RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile \
    && bin/magento setup:static-content:deploy -f -j $(nproc)

FROM davidalger/php:${PHP_VERSION}-fpm
COPY php.d/*.ini /etc/php.d/
COPY --from=build --chown=php-fpm:php-fpm /var/www/html /var/www/html
