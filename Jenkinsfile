#!/usr/bin/groovy
@Library('github.com/kadel/fabric8-pipeline-library@remove-JOB_NAME')
import io.fabric8.Fabric8Commands

def utils = new io.fabric8.Utils()

clientsNode{
  def envStage = utils.environmentNamespace('stage')
  def newVersion = ''
  def resourceName = utils.getResourceName()

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

  def rc = """
apiVersion: v1
kind: Pod
metadata:
  name: ${resourceName}
  labels:
    version: "${newVersion}"
spec:
  containers:
  - name: migration
    image: "${env.FABRIC8_DOCKER_REGISTRY_SERVICE_HOST}:${env.FABRIC8_DOCKER_REGISTRY_SERVICE_PORT}/${env.KUBERNETES_NAMESPACE}/${resourceName}:${newVersion}"
  restartPolicy: Never
  serviceAccount: che               
"""

  stage('Rollout to Stage')
  kubernetesApply(file: rc, environment: envStage)
}