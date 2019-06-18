FROM davidalger/php:7.2-fpm-alpine

ARG COMPOSER_AUTH
ENV MAGENTO_VERSION     2.3.1

RUN composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-community-edition ./ ${MAGENTO_VERSION} \
    && rm -rf "$(composer config -g home)"

RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile
