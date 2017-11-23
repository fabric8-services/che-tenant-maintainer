#!/bin/bash

set -e

echo "Compiling Ceylon project in directory '$(pwd)' ..."

ceylon compile
ceylon plugin install ceylon.swarm/1.3.3 || true
ceylon swarm --provided-module=javax:javaee-api --provided-module=io.undertow:undertow-servlet --swarm-version=2017.11.0 io.fabric8.tenant.che.migration.namespace io.fabric8.tenant.che.migration.workspaces io.fabric8.tenant.che.migration.rest
