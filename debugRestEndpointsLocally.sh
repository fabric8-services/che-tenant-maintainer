#!/bin/bash

script=$(readlink -f "$0")
dir=$(dirname "$script")

export JAVA_OPTS=-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=8000
./startRestEndpointsLocally.sh
