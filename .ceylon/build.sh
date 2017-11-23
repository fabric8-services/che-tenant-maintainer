#!/bin/bash

set -e

echo "Compiling Ceylon project in directory '$(pwd)' ..."

ceylon compile
ceylon plugin install ceylon.swarm/1.3.3 || true
ceylon swarm --provided-module=javax:javaee-api io.fabric8.tenant.che.migration.namespace io.fabric8.tenant.che.migration.workspaces io.fabric8.tenant.che.migration.rest
