#!/usr/bin/env bash

MIGRATION_DEBUG=${MIGRATION_DEBUG:-"false"}
MIGRATION_JAVA_OPTIONS=${MIGRATION_JAVA_OPTIONS:-""}

oc process -f migration-settings-cm.yml \
    -p DEBUG="${MIGRATION_DEBUG}" \
    -p JAVA_OPTIONS="${MIGRATION_JAVA_OPTIONS}" \
    | oc apply --force -f -
