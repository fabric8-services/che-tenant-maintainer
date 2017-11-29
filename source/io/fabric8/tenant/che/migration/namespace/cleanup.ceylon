import io.fabric8.kubernetes.api.model {
    ConfigMap,
    Service,
    HasMetadata,
    Pod
}
import io.fabric8.kubernetes.api.model.extensions {
    Deployment,
    ReplicaSet
}
import io.fabric8.openshift.api.model {
    Route,
    DeploymentConfig
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import io.fabric8.tenant.che.migration.workspaces {
    log
}

import java.lang {
    Thread,
    InterruptedException,
    JavaString=String
}
import java.util {
    JavaMap=Map
}

Map<String, String> toCeylon(JavaMap<JavaString, JavaString> javaMap) =>
        map { for (e in javaMap.entrySet()) e.key.string -> e.\ivalue.string };

Boolean isCheServerPod(Pod pod)
        => toCeylon(pod.metadata.labels).containsEvery {
            "deploymentconfig" -> "che"
        };

Boolean shouldBeDeleted(HasMetadata resource) {
    log.debug("Checking whether the following resource should be deleted '`` resource.kind `` : `` resource.metadata.name ``'" );

    value result = switch(r = resource)

    case(is DeploymentConfig)
        r.metadata.name == "che"

    case(is Route)
        r.metadata.name == "che"

    case (is Service)
        toCeylon(r.spec.selector).containsEvery {
            "app"->"che",
            "group" -> "io.fabric8.tenant.apps"
        }

    case (is Deployment)
        false

    case (is ReplicaSet)
        false

    case (is ConfigMap)
        r.metadata.name == "che"

    case (is Pod)
        isCheServerPod(r)

    else false;

    log.debug("    ====> `` if (result) then "DELETE" else "KEEP" ``");

    return result;
}

Boolean cleanSingleTenantCheServer() {
    try(oc = DefaultOpenShiftClient()) {
        String namespace = osioCheNamespace(oc);

        log.info("Stopping the Che server in namespace `` namespace ``");

        value cheServerDeploymentConfig =>
                oc.deploymentConfigs()
                    .inNamespace(namespace)
                    .withName(cheSingleTenantCheServerName);
        cheServerDeploymentConfig?.scale(0, true);

        value cheServerPods => { *oc.pods().inNamespace(namespace).list().items }
        .filter(isCheServerPod);

        value timeoutMinutes = 2;
        try {
            for(retry in 0:timeoutMinutes*60) {
                if (cheServerPods.empty) {
                    break;
                }
                Thread.sleep(1000);
            } else {
                // timeout reached
                log.error("Single-tenant Che server Pod could not be stopped, even after a `` timeoutMinutes `` minutes timeout");
                return false;
            }
        } catch(InterruptedException ie) {
            log.error("Interruped while waiting for the Che server pod termination", ie);
            return false;
        }

        void delete(HasMetadata resource) {
            oc.resource(resource).delete();
        }

        log.info("Cleaning single-tenant OpenShift resources in namespace `` namespace ``");

        value resourceTypes = {
            oc.routes(),
            oc.services(),
            oc.extensions().deployments(),
            oc.extensions().replicaSets(),
            oc.configMaps(),
            oc.deploymentConfigs()
        };

        resourceTypes
            .map((resType)=> resType.inNamespace(namespace).list().items)
            .flatMap((list) => { *list } )
            .filter(shouldBeDeleted)
            .each(delete);

        try {
            for(retry in 0:timeoutMinutes*60) {
                if (! cheServerDeploymentConfig?.get() exists) {
                    break;
                }
                Thread.sleep(1000);
            } else {
                // timeout reached
                log.error("Single-tenant Che server deployment config could not deleted, even after a `` timeoutMinutes `` minutes timeout");
                return false;
            }
        } catch(InterruptedException ie) {
            log.error("Interruped while waiting for the Che server pod termination", ie);
            return false;
        }

    }
    return true;
}

void cleanMigrationResources() {
    try(oc = DefaultOpenShiftClient()) {
        if (exists configMap = oc.configMaps().inNamespace(osioCheNamespace(oc)).withName("migration").get()) {
            oc.resource(configMap).delete();
        }
    } catch(Exception e) {
        log.warn("Exception while cleaning the migration Openshift resources", e);
    }
}
