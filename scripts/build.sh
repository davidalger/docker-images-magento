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
  if [[ ${DOCKER_USERNAME:-} ]]; then
    echo "Attempting non-interactive docker login (via provided credentials)"
    echo "${DOCKER_PASSWORD:-}" | docker login -u "${DOCKER_USERNAME:-}" --password-stdin ${DOCKER_REGISTRY:-}
  elif [[ ${AWS_ACCESS_KEY_ID:-} ]] || [[ ${AWS_PROFILE:-} ]]; then
    echo "Attempting non-interactive docker login (via aws ecr get-login)"
    $(aws ecr get-login --no-include-email --region us-east-1)
  elif [[ -t 1 ]]; then
    echo "Attempting interactive docker login (tty)"
    docker login
  fi
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

    ## Create isolated network so build can connect to database for install
    NETWORK_NAME="build_$(openssl rand -base64 32 | sed 's/[^a-z0-9]//g' | colrm 13)"
    docker network create "${NETWORK_NAME}"

    ## Start mariadb container allowing build to generate database artifact
    MARIADB_NAME="mariadb_$(openssl rand -base64 32 | sed 's/[^a-z0-9]//g' | colrm 13)"
    docker run --rm -d \
      --name "${MARIADB_NAME}" \
      --network "${NETWORK_NAME}" \
      --network-alias mariadb \
      -e MYSQL_DATABASE=magento \
      -e MYSQL_USER=magento \
      -e MYSQL_PASSWORD=magento \
      -e MYSQL_RANDOM_ROOT_PASSWORD=true \
      mariadb:10.3

    ## Initiate the Dockerfile build
    docker build "${IMAGE_TAGS[@]}" --network "${NETWORK_NAME}" \
        --build-arg COMPOSER_AUTH --build-arg PHP_VERSION \
        --build-arg MAGENTO_VERSION --build-arg MAGENTO_EDITION \
        -f "${Dockerfile}" "${BASE_DIR}/context"

    ## Dump generated database to artifact for imaged container to pre-load on startup
    docker exec "${MARIADB_NAME}" bash -c 'mysqldump -umagento -pmagento magento \
      | gzip -c > /docker-entrypoint-initdb.d/artifact.sql.gz'

    ## Commit and push images to regsistry
    for IMAGE_TAG in "${IMAGE_TAGS[@]}"; do
      if [[ "${IMAGE_TAG}" = "-t" ]]; then
        continue
      fi

      MARIADB_TAG="$(echo "${IMAGE_TAG}" | sed 's/'"${IMAGE_SUFFIX}"'$/-mariadb&/')"
      docker commit "${MARIADB_NAME}" "${MARIADB_TAG}"
      echo "Successfully tagged ${MARIADB_TAG}"

      if [[ ${PUSH_FLAG} ]]; then
        docker image push "${IMAGE_TAG}"
        docker image push "${MARIADB_TAG}"
      fi
    done

    ## Cleanup containers and networks started for build process
    docker kill "${MARIADB_NAME}"
    docker network rm "${NETWORK_NAME}"
  done
done
