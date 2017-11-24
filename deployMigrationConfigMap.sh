#!/usr/bin/env bash

if [ "${OSIO_TOKEN}" == "" ]; then
    echo "The OSIO_TOKEN env variable should be set with your token"
    exit 1
fi

oc process -f migration-cm.yml \
    -p OSIO_TOKEN="${OSIO_TOKEN}" \
    | oc apply --force -f -
