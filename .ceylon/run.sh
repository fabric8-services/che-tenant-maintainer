#!/bin/bash

set -e

cd $(dirname $0)/..

ceylon run io.fabric8.tenant.che.migration.namespace
