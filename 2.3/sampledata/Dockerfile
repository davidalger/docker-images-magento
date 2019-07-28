FROM davidalger/warden:mage2-fpm-7.2

ARG COMPOSER_AUTH
ARG MAGENTO_VERSION

RUN rmdir /var/www/html/pub \
    && composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-community-edition /var/www/html ${MAGENTO_VERSION} \
    && rm -rf "$(composer config -g home)"

RUN bin/magento sampledata:deploy && rm -rf var/composer_home

RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile
