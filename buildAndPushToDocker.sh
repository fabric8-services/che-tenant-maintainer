#!/usr/bin/env bash
set -e

REGISTRY=${REGISTRY:-"quay.io"}
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

if [[ "$TARGET" == "rhel" ]]; then
    IMAGE=${REGISTRY}/rhel-${NAMESPACE}-fabric8-tenant-che-migration
else
    IMAGE=${REGISTRY}/${NAMESPACE}-fabric8-tenant-che-migration
fi

[ -n "$TAG" ] && tag_push ${IMAGE}:${TAG}
tag_push ${IMAGE}:latest
