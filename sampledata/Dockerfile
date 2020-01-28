ARG PHP_VERSION=
FROM davidalger/php:${PHP_VERSION}-fpm as build

ARG COMPOSER_AUTH
ARG COMPOSER_PKGS
ARG MAGENTO_VERSION
ARG MAGENTO_EDITION

COPY composer-cache /root/.composer/cache
COPY php.d/*.ini /etc/php.d/

WORKDIR /var/www/html

RUN composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-${MAGENTO_EDITION}-edition /var/www/html ${MAGENTO_VERSION}

RUN if [[ ${COMPOSER_PKGS} ]]; \
        then composer require --no-interaction ${COMPOSER_PKGS}; \
    fi

## Install sampledata modules
RUN mkdir -p var/composer_home \
    && ln -s /root/.composer/cache var/composer_home/cache \
    && bin/magento sampledata:deploy \
    && find var -maxdepth 1 '!' -name var '!' -name .htaccess -exec rm -rvf {} +

COPY config.php app/etc/config.php
RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile \
    && bin/magento setup:static-content:deploy -f -j $(nproc) \
    && find var -maxdepth 1 '!' -name var '!' -name .htaccess -exec rm -rvf {} +

## Requires aliased mariadb container on build network; see build.sh for details
RUN bin/magento setup:install --cleanup-database \
        --db-host=mariadb --db-name=magento --db-user=magento --db-password=magento \
    && bin/magento catalog:images:resize \
    && rm -f app/etc/env.php \
    && find var -maxdepth 1 '!' -name var '!' -name .htaccess -exec rm -rvf {} +

FROM davidalger/php:${PHP_VERSION}-fpm
COPY php.d/*.ini /etc/php.d/
COPY --from=build --chown=php-fpm:php-fpm /var/www/html /var/www/html
