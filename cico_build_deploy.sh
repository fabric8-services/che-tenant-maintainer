#!/bin/bash

# Output command before executing
set -x

# Exit on error
set -e

REGISTRY=${REGISTRY:-quay.io}

# TARGET variable gives ability to switch context for building rhel based images, default is "centos"
# If CI slave is configured with TARGET="rhel" RHEL based images should be generated then.
TARGET=${TARGET:-"centos"}

if [ $TARGET == "rhel" ]; then
  DOCKERFILE="Dockerfile.rhel"
else
  DOCKERFILE="Dockerfile"
fi
NAMESPACE=${NAMESPACE:-"fabric8-services"}

# Source environment variables of the jenkins slave
# that might interest this worker.
function load_jenkins_vars() {
  if [ -e "jenkins-env.json" ]; then
    eval "$(./env-toolkit load -f jenkins-env.json \
            DEVSHIFT_TAG_LEN \
            QUAY_USERNAME \
            QUAY_PASSWORD \
            JENKINS_URL \
            GIT_BRANCH \
            GIT_COMMIT \
            BUILD_NUMBER \
            ghprbSourceBranch \
            ghprbActualCommit \
            BUILD_URL \
            ghprbPullId)"
  fi
}

function login() {
  if [ -n "${QUAY_USERNAME}" -a -n "${QUAY_PASSWORD}" ]; then
    docker login -u ${QUAY_USERNAME} -p ${QUAY_PASSWORD} ${REGISTRY}
  else
    echo "Could not login, missing credentials for the registry"
  fi
}

 # We need to disable selinux for now, XXX
/usr/sbin/setenforce 0 || true

# Get all the deps in
yum -y install \
   docker \
   java-1.8.0-openjdk-devel \
   make \
   git \
   curl \
   go

go get github.com/openshift/source-to-image/cmd/s2i
export PATH=${PATH}:~/go/bin

load_jenkins_vars
TAG=$(echo $GIT_COMMIT | cut -c1-${DEVSHIFT_TAG_LEN})

service docker start
login

export ADD_REST_ENDPOINTS=true
export S2I_BUILD=false
source ./buildAndPushToDocker.sh

echo 'CICO: Image pushed, ready to update deployed app'
