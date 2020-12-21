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
    && bin/magento sampledata:deploy

COPY config.php app/etc/config.php
RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile \
    && bin/magento setup:static-content:deploy -f -j $(nproc)

## Requires mariadb and elasticsearch container on build network; see build.sh for details
RUN if [[ ${MAGENTO_VERSION} =~ ^2\.[4-9] ]]; then \
      bin/magento setup:install --cleanup-database \
        --db-host=mariadb --db-name=magento --db-user=magento --db-password=magento \
        --search-engine=elasticsearch7 --elasticsearch-host=elasticsearch; \
    else \
      bin/magento setup:install --cleanup-database \
        --db-host=mariadb --db-name=magento --db-user=magento --db-password=magento; \
    fi

## Clean all the cruft out before copying files into final image
RUN find var app/etc/env.php -maxdepth 1 '!' -name var '!' -name .htaccess -exec rm -rf {} +

FROM davidalger/php:${PHP_VERSION}-fpm
COPY php.d/*.ini /etc/php.d/
COPY --from=build --chown=apache:apache /var/www/html /var/www/html
