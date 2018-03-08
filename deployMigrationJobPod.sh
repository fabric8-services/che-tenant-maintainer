#!/usr/bin/env bash

if [ "$1" == "" ]; then
    echo
    echo "ERROR: Please add the prefix of the migration you want to use"
    echo "It will then search for the <prefix>-migration-cm.yaml file"
    exit 1
fi

if [ "${OSIO_TOKEN}" == "" ]; then
    echo
    echo "The OSIO_TOKEN env variable should be set with your token"
    exit 1
fi

MIGRATION_VERSION=${MIGRATION_VERSION:-latest}
MIGRATION_IMAGE=${MIGRATION_IMAGE:-"docker.io/dfestal/fabric8-tenant-che-migration:latest"}
REQUEST_ID=${RANDOM}

oc process -f $1-migration-cm.yml \
    -p OSIO_TOKEN="${OSIO_TOKEN}" \
    -p REQUEST_ID="${REQUEST_ID}" \
    | oc apply --overwrite=true --force -f -


oc process -f migration-job.yml \
    -p IMAGE="${MIGRATION_IMAGE}" \
    -p REQUEST_ID="${REQUEST_ID}" \
    | oc apply --overwrite=true --force -f -
