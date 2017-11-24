#!/bin/bash

set -e

ADD_REST_ENDPOINTS=${ADD_REST_ENDPOINTS:-false}

echo "Compiling Ceylon project in directory '$(pwd)' ..."

if [ "${ADD_REST_ENDPOINTS}" == "true" ]; then
    ceylon compile
else
    ceylon compile io.fabric8.tenant.che.migration.namespace io.fabric8.tenant.che.migration.workspaces
fi

rm io.fabric8.tenant.che.migration.*.jar 2> /dev/null || true
rm io.fabric8.tenant.che.migration.*.war 2> /dev/null || true

if [ "${ADD_REST_ENDPOINTS}" == "true" ]; then
    echo
    echo "Create the Wildfly Swarm application ..."

    ceylon plugin install ceylon.swarm/1.3.3 || true
    ceylon swarm --provided-module=javax.ws.rs:javax.ws.rs-api --provided-module=io.undertow:undertow-servlet --provided-module=org.jboss.weld:weld-core-impl io.fabric8.tenant.che.migration.rest
    mv io.fabric8.tenant.che.migration.rest-*-swarm.jar io.fabric8.tenant.che.migration.rest.jar
else
    echo
    echo "Wildfly Swarm application creation skipped..."
    echo "... set the ADD_REST_ENDPOINTS variable to 'true' in order to also build the REST application"
    echo
fi