#!/usr/bin/env bash
set -e

REGISTRY=${REGISTRY:-"docker.io"}
NAMESPACE=${NAMESPACE:-"dfestal"}
ADD_REST_ENDPOINTS=${ADD_REST_ENDPOINTS:-false}

function tag_push() {
  TARGET=$1
  docker tag f8tenant-che-migration-deploy $TARGET
  docker push $TARGET
}

s2i build -e ADD_REST_ENDPOINTS="${ADD_REST_ENDPOINTS}" -c . ceylon/s2i-ceylon:1.3.3-jre8 f8tenant-che-migration-deploy

if [ "$TAG" != "" ];
then
  tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:$TAG
fi
tag_push ${REGISTRY}/${NAMESPACE}/fabric8-tenant-che-migration:latest
