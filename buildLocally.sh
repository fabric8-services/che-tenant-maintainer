#!/usr/bin/env bash
set -e

ceylon() {
  ./ceylonb $*
}

source ./.ceylon/build.sh