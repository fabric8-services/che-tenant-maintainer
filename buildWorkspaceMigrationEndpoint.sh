#!/bin/bash

set -e

echo "Compiling..."

./ceylonb compile

echo
echo "Building the Wildfly Swarm archive..."

./ceylonb swarm --provided-module=javax:javaee-api io.fabric8.tenant.che.migration.workspaces
