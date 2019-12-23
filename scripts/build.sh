#!/usr/bin/env bash
set -e
trap '>&2 printf "\n\e[01;31mError: Command \`%s\` on line $LINENO failed with exit code $?\033[0m\n" "$BASH_COMMAND"' ERR

## find directory where this script is located following symlinks if neccessary
readonly BASE_DIR="$(
  cd "$(
    dirname "$(
      (readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}") \
        | sed -e "s#^../#$(dirname "$(dirname "${BASH_SOURCE[0]}")")/#"
    )"
  )" >/dev/null \
  && pwd
)/.."
pushd ${BASE_DIR} >/dev/null

## if --push is passed as first argument to script, this will login to docker hub and push images
PUSH_FLAG=
if [[ "${1:-}" = "--push" ]]; then
  PUSH_FLAG=1
fi

## login to docker hub as needed
if [[ ${PUSH_FLAG} ]]; then
  [ -t 1 ] && docker login \
    || echo "${DOCKER_PASSWORD:-}" | docker login -u "${DOCKER_USERNAME:-}" --password-stdin ${DOCKER_REGISTRY:-}
fi

## space separated list of versions to build
PHP_VERSION="${PHP_VERSION:-7.3}"
BUILD_VERSIONS="${BUILD_VERSIONS:-2.3.x}"
LATEST_VERSION="$(echo ${BUILD_VERSIONS} | awk '{print $NF}')"
MAGENTO_EDITION="${MAGENTO_EDITION:-community}"

## iterate over and build each Dockerfile
for Dockerfile in $(find . -type f -name Dockerfile | sort -n); do
  IMAGE_NAME="${IMAGE_NAME:-davidalger/magento}"
  COMPOSER_AUTH="${COMPOSER_AUTH:-"$(cat "$(composer config -g home)/auth.json")"}"

  for MAGENTO_VERSION in ${BUILD_VERSIONS}; do
    IMAGE_TAGS=()

    IMAGE_SUFFIX="$(basename $(dirname "${Dockerfile}") | tr / - | sed 's/--/-/')"
    if [[ ${IMAGE_SUFFIX} = "." ]]; then
      IMAGE_SUFFIX=
    else
      IMAGE_SUFFIX="-${IMAGE_SUFFIX}"
    fi

    if [[ ! ${MAGENTO_VERSION} =~ x$ ]]; then
      IMAGE_TAGS+=("-t" "${IMAGE_NAME}:${MAGENTO_VERSION}${IMAGE_SUFFIX}")
    fi

    if [[ ${LATEST_VERSION} = ${MAGENTO_VERSION} ]]; then
      IMAGE_TAGS+=("-t" "${IMAGE_NAME}:$(echo ${MAGENTO_VERSION} | cut -d. -f1-2)${IMAGE_SUFFIX}")
    fi

    export COMPOSER_AUTH PHP_VERSION MAGENTO_VERSION MAGENTO_EDITION
    printf "\e[01;31m==> building ${IMAGE_TAGS[*]}\033[0m\n"
    docker build "${IMAGE_TAGS[@]}" \
        --build-arg COMPOSER_AUTH --build-arg PHP_VERSION \
        --build-arg MAGENTO_VERSION --build-arg MAGENTO_EDITION \
        -f "${Dockerfile}" "${BASE_DIR}/context"

    for tag in "${IMAGE_TAGS[@]}"; do
      if [[ "${tag}" = "-t" ]]; then
        continue
      fi
      if [[ ${PUSH_FLAG} ]]; then
        docker push "${tag}"
      fi
    done
  done
done
