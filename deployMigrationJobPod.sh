#!/usr/bin/env bash

if [ "${OSIO_TOKEN}" == "" ]; then
    echo "The OSIO_TOKEN env variable should be set with your token"
    exit 1
fi

MIGRATION_VERSION=${MIGRATION_VERSION:-latest}
MIGRATION_IMAGE=${MIGRATION_IMAGE:-"docker.io/dfestal/fabric8-tenant-che-migration:latest"}
CLEANUP_SINGLE_TENANT=${CLEANUP_SINGLE_TENANT:-"true"}
CHE_MULTITENANT_SERVER=${CHE_MULTITENANT_SERVER:-"https://che-dfestal-che.glusterpoc37aws.devshift.net"}
REQUEST_ID=${RANDOM}

oc process -f migration-cm.yml \
    -p OSIO_TOKEN="${OSIO_TOKEN}" \
    -p CLEANUP_SINGLE_TENANT="${CLEANUP_SINGLE_TENANT}" \
    -p CHE_MULTITENANT_SERVER="${CHE_MULTITENANT_SERVER}" \
    -p REQUEST_ID="${REQUEST_ID}" \
    | oc apply --overwrite=true --force -f -


oc process -f namespace-migration.yml \
    -p IMAGE="${MIGRATION_IMAGE}" \
    -p REQUEST_ID="${REQUEST_ID}" \
    | oc apply --overwrite=true --force -f -
