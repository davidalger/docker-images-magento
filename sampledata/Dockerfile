ARG PHP_VERSION=
FROM davidalger/php:${PHP_VERSION}-fpm as build

ARG COMPOSER_AUTH
ARG MAGENTO_VERSION
ARG MAGENTO_EDITION

COPY composer-cache /root/.composer/cache
COPY php.d/*.ini /etc/php.d/

WORKDIR /var/www/html

RUN composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-${MAGENTO_EDITION}-edition /var/www/html ${MAGENTO_VERSION}

## Install sampledata modules
RUN mkdir -p var/composer_home \
    && ln -s /root/.composer/cache var/composer_home/cache \
    && bin/magento sampledata:deploy \
    && rm -rf var/composer_home

## Install CSS fixtures normally placed during setup:install
RUN find vendor/magento -type f -path '*/module-*/fixtures/*' -name styles.css \
        | xargs -r cat >> pub/media/styles.css

COPY config.php app/etc/config.php
RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile \
    && bin/magento setup:static-content:deploy -f -j $(nproc)

FROM davidalger/php:${PHP_VERSION}-fpm
COPY php.d/*.ini /etc/php.d/
COPY --from=build --chown=php-fpm:php-fpm /var/www/html /var/www/html
