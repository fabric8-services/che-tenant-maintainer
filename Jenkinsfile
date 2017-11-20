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
    {
      "apiVersion" : "v1",
      "kind" : "Template",
      "labels" : { },
      "metadata" : {
        "annotations" : {
          "description" : "Fabric8 namespace migration Ceylon tool",
          "fabric8.${resourceName}/iconUrl" : "https://raw.githubusercontent.com/eclipse/che/master/ide/che-core-ide-stacks/src/main/resources/stacks-images/type-ceylon.svg"
        },
        "labels" : { },
        "name" : "${resourceName}"
      },
      "objects" : [{
        "kind": "ReplicationController",
        "apiVersion": "v1",
        "metadata": {
            "name": "${resourceName}",
            "generation": 1,
            "creationTimestamp": null,
            "labels": {
                "component": "${resourceName}",
                "container": "java",
                "group": "fabric8-migration",
                "project": "${resourceName}",
                "provider": "fabric8",
                "expose": "true",
                "version": "${newVersion}"
            },
            "annotations": {
                "fabric8.${resourceName}/iconUrl" : "https://raw.githubusercontent.com/eclipse/che/master/ide/che-core-ide-stacks/src/main/resources/stacks-images/type-ceylon.svg"
            }
        },
        "spec": {
            "replicas": 1,
            "selector": {
                "component": "${resourceName}",
                "container": "java",
                "group": "fabric8-migration",
                "project": "${resourceName}",
                "provider": "fabric8",
                "version": "${newVersion}"
            },
            "template": {
                "metadata": {
                    "creationTimestamp": null,
                    "labels": {
                        "component": "${resourceName}",
                        "container": "java",
                        "group": "fabric8-migration",
                        "project": "${resourceName}",
                        "provider": "fabric8",
                        "version": "${newVersion}"
                    }
                },
                "spec": {
                    "containers": [
                        {
                            "name": "${resourceName}",
                            "image": "${env.FABRIC8_DOCKER_REGISTRY_SERVICE_HOST}:${env.FABRIC8_DOCKER_REGISTRY_SERVICE_PORT}/${env.KUBERNETES_NAMESPACE}/${resourceName}:${newVersion}",
                            "ports": [],
                            "env": [
                                {
                                    "name": "KUBERNETES_NAMESPACE",
                                    "valueFrom": {
                                        "fieldRef": {
                                            "apiVersion": "v1",
                                            "fieldPath": "metadata.namespace"
                                        }
                                    }
                                }
                            ],
                            "resources": {},
                            "terminationMessagePath": "/dev/termination-log",
                            "imagePullPolicy": "IfNotPresent",
                            "securityContext": {}
                        }
                    ],
                    "restartPolicy": "OnFailure",
                    "terminationGracePeriodSeconds": 30,
                    "dnsPolicy": "ClusterFirst",
                    "securityContext": {}
                }
            }
        },
        "status": {
            "replicas": 0
        }
    }]}
    """

  stage('Rollout to Stage')
  kubernetesApply(file: rc, environment: envStage)
}