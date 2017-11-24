#!/usr/bin/groovy

@Library('github.com/fabric8io/fabric8-pipeline-library@master')
import io.fabric8.Fabric8Commands

def utils = new io.fabric8.Utils()

clientsNode{
  def envStage = utils.environmentNamespace('stage')
  def newVersion = ''
  def resourceName = utils.getRepoName()

  checkout scm
  stage('Build Release')
  echo 'NOTE: running pipelines for the first time will take longer as build and base docker images are pulled onto the node'


  container('clients') {
    if (newVersion == '') {
        newVersion = getNewVersion {}
    }

    env.setProperty('VERSION', newVersion)

    def flow = new Fabric8Commands()
    if (flow.isOpenShift()) {
        def ns = utils.namespace
        def is = """
apiVersion: v1
kind: ImageStream
metadata:
  name: ${resourceName}
  namespace: ${ns}
"""
        def bc = """
apiVersion: v1
kind: BuildConfig
metadata:
  name: ${resourceName}-s2i
  namespace: ${ns}
spec:
  output:
    to:
      kind: ImageStreamTag
      name: ${resourceName}:${newVersion}
  runPolicy: Serial
  source:
    type: Binary
  strategy:
    sourceStrategy:
      from:
        kind: "DockerImage"
        name: "ceylon/s2i-ceylon:1.3.3-jre8"
"""    
    
        sh "oc delete is ${resourceName} -n ${ns} || true"
        kubernetesApply(file: is, environment: ns)
        kubernetesApply(file: bc, environment: ns)
        sh "oc start-build ${resourceName}-s2i --from-dir ./ --follow -n ${ns}"
    } else {
        echo 'NOTE: Not on Openshift: do nothing since it is not implemented for now'
    }
  }

  stage('Rollout to Stage')
  def migrationImage = "${resourceName}:${newVersion}"
  def isSha = utils.getImageStreamSha(resourceName)
  def ns = utils.namespace

  def isForDeployment = """
apiVersion: v1
kind: ImageStream
metadata:
name: ${resourceName}
spec:
tags:
- from:
    kind: ImageStreamImage
    name: ${resourceName}@${isSha}
    namespace: ${utils.getNamespace()}
  name: ${newVersion}
"""
  echo "About to apply the following to openshift: ${isForDeployment}"
  kubernetesApply(file: isForDeployment, environment: envStage)

  def deployment = sh(returnStdout: true, script: "oc process -f migration-endpoints.yml -v IMAGE=\"${migrationImage}\" -v VERSION=\"${newVersion}\"")
  echo "About to apply the following to openshift: ${deployment}"
  kubernetesApply(file: toApply, environment: envStage)
}