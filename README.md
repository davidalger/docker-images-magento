# Docker Images for Magento Demo Environment

* https://github.com/davidalger/m2demo/
* https://hub.docker.com/r/davidalger/magento

## About These Images

Docker images for use with [Warden](https://warden.dev/) based [Magento 2 Demo Environment](https://github.com/magento/magento2/) or similar container based demo environment. Essentially these images are a deployable Magento artifact based on the `davidalger/php:7.*-fpm` with or without sample data. They can be used as an init-container in a Kubernetes Pod or leveraged (as they are by the linked demo environment) to pre-load data into a volume within a docker-compose stack.

## License

This work is licensed under the MIT license. See LICENSE file for details.

## Author Information

This project was started in 2019 by [David Alger](https://davidalger.com/).
