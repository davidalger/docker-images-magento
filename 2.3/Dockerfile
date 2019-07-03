FROM davidalger/php:7.2-fpm

ARG COMPOSER_AUTH
ARG MAGENTO_VERSION

RUN composer global require hirak/prestissimo \
    && composer create-project --no-interaction --repository=https://repo.magento.com/ \
        magento/project-community-edition ./ ${MAGENTO_VERSION} \
    && rm -rf "$(composer config -g home)"

COPY etc/profile.d/*.sh /etc/profile.d/
COPY etc/php.d/*.ini /etc/php.d/

RUN bin/magento module:enable --all \
    && bin/magento setup:di:compile
