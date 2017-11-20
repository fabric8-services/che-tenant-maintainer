#!/bin/bash

set -e

cd $(dirname $0)/..

echo "Compiling..."

ceylon compile
