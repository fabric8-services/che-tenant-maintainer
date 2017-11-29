#!/usr/bin/env bash

DEBUG=${MIGRATION_DEBUG:-"false"}
JAVA_TOOL_OPTIONS=${MIGRATION_JAVA_OPTIONS:-""}

oc process -f migration-settings-cm.yml \
    -p DEBUG="${MIGRATION_DEBUG}" \
    -p JAVA_TOOL_OPTIONS="${MIGRATION_JAVA_OPTIONS}" \
    | oc apply --force -f -
