#!/usr/bin/env bash
set -e

REGISTRY=${REGISTRY:-"docker.io"}
NAMESPACE=${NAMESPACE:-"dfestal"}
ADD_REST_ENDPOINTS=${ADD_REST_ENDPOINTS:-false}
DOCKERFILE=${DOCKERFILE:-"Dockerfile"}

function tag_push() {
  local TARGET=$1
  docker tag f8tenant-che-migration-deploy $TARGET
  docker push $TARGET
}

if [ "$S2I_BUILD" == "true" ]; then
  s2i build -e ADD_REST_ENDPOINTS="${ADD_REST_ENDPOINTS}" -c . ceylon/s2i-ceylon:1.3.3-jre8 f8tenant-che-migration-deploy
else
  ./buildLocally.sh
  docker build -t f8tenant-che-migration-deploy -f ${DOCKERFILE} .
fi


if [ "$TAG" != "" ];
then
  tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:$TAG
fi
tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:latest
