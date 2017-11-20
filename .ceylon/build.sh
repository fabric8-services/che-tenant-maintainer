#!/bin/bash

echo "In the custom build.sh !!!"

set -e

cd $(dirname $0)/..

echo "current dir : $(pwd)"
echo "current dir contents : $(ls -R)"

echo "Compiling..."

ceylon compile
