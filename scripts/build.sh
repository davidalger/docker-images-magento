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
  SEARCH_PATH="${2:-*}"
else
  SEARCH_PATH="${1:-*}"
fi

## login to docker hub as needed
if [[ $PUSH_FLAG ]]; then
  [ -t 1 ] && docker login \
    || echo "${DOCKER_PASSWORD:-}" | docker login -u "${DOCKER_USERNAME:-}" --password-stdin
fi

## space separated list of versions to build
BUILD_VERSIONS="${BUILD_VERSIONS:-2.3.2 2.3.1 2.3.0}"
LATEST_VERSION="$(echo ${BUILD_VERSIONS} | awk '{print $1}')"

## iterate over and build each Dockerfile
for file in $(find ${SEARCH_PATH} -type f -name Dockerfile); do
  BUILD_DIR="$(dirname "${file}")"
  COMPOSER_AUTH="$(cat "$(composer config -g home)/auth.json")"

  for MAGENTO_VERSION in ${BUILD_VERSIONS}; do
    IMAGE_TAGS=-t\ "davidalger/magento:${MAGENTO_VERSION}"
    if [[ ! ${MAGENTO_VERSION} =~ ^$(basename $(dirname "${file}")) ]]; then
      IMAGE_TAGS+=-$(basename $(dirname "${file}"))
    fi

    if [[ ${LATEST_VERSION} = ${MAGENTO_VERSION} ]]; then
      IMAGE_TAGS+=\ -t\ "davidalger/magento:$(dirname "${file}" | tr / - | sed 's/--/-/')"
    fi

    export COMPOSER_AUTH MAGENTO_VERSION
    docker build ${IMAGE_TAGS} --build-arg COMPOSER_AUTH --build-arg MAGENTO_VERSION \
       -f ${BUILD_DIR}/Dockerfile "$(echo ${BUILD_DIR} | cut -d/ -f1)"
    for tag in ${IMAGE_TAGS}; do
      if [[ ${tag} = "-t" ]]; then
        continue
      fi
      [[ $PUSH_FLAG ]] && docker push "${tag}"
    done
  done
done
