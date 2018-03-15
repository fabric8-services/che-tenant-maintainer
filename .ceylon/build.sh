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
    ceylon swarm  --swarm-version=2018.3.3 --dependencies=org.wildfly.swarm:jaxrs:2018.3.3 --provided-module=javax.ws.rs:javax.ws.rs-api io.fabric8.tenant.che.migration.rest
    mv io.fabric8.tenant.che.migration.rest-*-swarm.jar io.fabric8.tenant.che.migration.rest.jar

    mkdir -p agent-bond
    curl --fail http://central.maven.org/maven2/io/fabric8/agent-bond-agent/1.2.0/agent-bond-agent-1.2.0.jar -o agent-bond/agent-bond.jar
    curl --fail https://raw.githubusercontent.com/fabric8io-images/java/1.2.0/images/centos/openjdk8/jdk/java-container-options -o agent-bond/java-container-options
    curl --fail https://raw.githubusercontent.com/fabric8io-images/java/1.2.0/images/centos/openjdk8/jdk/agent-bond-opts -o agent-bond/agent-bond-opts
    chmod u+x agent-bond/*
else
    echo
    echo "Wildfly Swarm application creation skipped..."
    echo "... set the ADD_REST_ENDPOINTS variable to 'true' in order to also build the REST application"
    echo
fi