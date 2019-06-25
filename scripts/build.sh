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

## support passing a single argument to the command to be more specific on what is built
SEARCH_PATH="${1:-*}"

## change into base directory and login to docker hub if neccessary
pushd ${BASE_DIR} >/dev/null
docker login

CURRENT_VERSION="2.3.2"   # used to generate 2.3 tag
BUILD_VERSIONS="2.3.0 2.3.1 2.3.2"

## iterate over and build each Dockerfile
for file in $(find ${SEARCH_PATH} -type f -name Dockerfile); do
  BUILD_DIR="$(dirname "${file}")"
  COMPOSER_AUTH="$(cat "$(composer config -g home)/auth.json")"

  for MAGENTO_VERSION in ${BUILD_VERSIONS}; do
    IMAGE_TAGS=-t\ "davidalger/magento:${MAGENTO_VERSION}"
    if [[ ! ${MAGENTO_VERSION} =~ ^$(basename $(dirname "${file}")) ]]; then
      IMAGE_TAGS+=-$(basename $(dirname "${file}"))
    fi

    if [[ ${CURRENT_VERSION} = ${MAGENTO_VERSION} ]]; then
      IMAGE_TAGS+=\ -t\ "davidalger/magento:$(dirname "${file}" | tr / -)"
    fi

    export COMPOSER_AUTH MAGENTO_VERSION
    docker build ${IMAGE_TAGS} ${BUILD_DIR} --build-arg COMPOSER_AUTH --build-arg MAGENTO_VERSION
    for tag in ${IMAGE_TAGS}; do
      if [[ ${tag} = "-t" ]]; then
        continue
      fi
      docker push ${tag}
    done
  done
done
