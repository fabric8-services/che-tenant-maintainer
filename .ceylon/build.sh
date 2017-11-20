#!/bin/bash

echo "In the custom build.sh !!!"

set -e

echo "current dir : $(pwd)"
echo "current dir contents : $(ls -R)"

echo "Compiling..."

ceylon compile
