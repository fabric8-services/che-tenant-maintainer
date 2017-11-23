#!/usr/bin/env bash

MIGRATION_VERSION=${MIGRATION_VERSION:-latest}
MIGRATION_IMAGE=${MIGRATION_IMAGE:-"docker.io/dfestal/fabric8-tenant-che-migration:latest"}

oc process -f migration-endpoints.yml \
    -p IMAGE="${MIGRATION_IMAGE}" \
    -p VERSION="${MIGRATION_VERSION}" \
    | oc apply --force -f -
