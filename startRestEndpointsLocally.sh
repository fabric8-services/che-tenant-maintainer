#!/bin/bash

script=$(readlink -f "$0")
dir=$(dirname "$script")

# Combine all java options
get_java_options() {

  # Normalize spaces (i.e. trim and elimate double spaces)
  echo "${JAVA_OPTS} $($dir/agent-bond/agent-bond-opts) $($dir/agent-bond/java-container-options)" | awk '$1=$1'
}

export AB_DIR=$dir/agent-bond
export AB_ENABLED=jolokia

exec java $(get_java_options) -jar io.fabric8.tenant.che.migration.rest.jar