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

## if --push is passed as first argument to script, this will login to docker hub and push images
PUSH_FLAG=
if [[ "${1:-}" = "--push" ]]; then
  PUSH_FLAG=1
  SEARCH_PATH="${2:-*}"
else
  SEARCH_PATH="${1:-*}"
fi

## change into base directory and login to docker hub if neccessary
pushd ${BASE_DIR} >/dev/null
[[ $PUSH_FLAG ]] && docker login

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
