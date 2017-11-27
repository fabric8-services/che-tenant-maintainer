#!/usr/bin/env bash

MIGRATION_VERSION=${MIGRATION_VERSION:-latest}
MIGRATION_IMAGE=${MIGRATION_IMAGE:-"docker.io/dfestal/fabric8-tenant-che-migration:latest"}
CLEANUP_SINGLE_TENANT=${CLEANUP_SINGLE_TENANT:-"true"}
DEBUG=${DEBUG:-"false"}

oc process -f namespace-migration.yml \
    -p IMAGE="${MIGRATION_IMAGE}" \
    -p VERSION="${MIGRATION_VERSION}" \
    -p CLEANUP_SINGLE_TENANT="${CLEANUP_SINGLE_TENANT}" \
    -p DEBUG="${DEBUG}" \
    | oc apply --force -f -
