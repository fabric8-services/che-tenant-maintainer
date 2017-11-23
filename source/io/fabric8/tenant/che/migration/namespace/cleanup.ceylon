import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import  io.fabric8.openshift.api.model {
    Route
}
import io.fabric8.kubernetes.api.model {
    ConfigMap,
    Service,
    HasMetadata,
    Pod
}
import io.fabric8.tenant.che.migration.workspaces {
    log
}
import io.fabric8.kubernetes.api.model.extensions {
    Deployment,
    ReplicaSet
}
import java.lang {
    Thread,
    InterruptedException,
    Types { str = nativeString }
}

Boolean shouldBeDeleted(HasMetadata resource) {
    log.debug("Checking whether the following resource should be deleted: `` resource ``");

    value result = switch(r = resource)
    case(is Route)
        r.metadata.name == "che"

    case (is Service)
        every {
            if (exists app = r.spec.selector[str("app")]?.string) then app == "che" else false,
            if (exists group = r.spec.selector[str("group")]?.string) then group == "io.fabric8.tenant.apps" else false
        }

    case (is Deployment)
        r.metadata.name == "che"

    case (is ReplicaSet)
        r.metadata.name == "che"

    case (is ConfigMap)
        r.metadata.name == "che"

    case (is Pod)
        if (exists label = r.metadata.labels[str("deploymentconfig")]?.string) then label=="che" else false

    else false;

    log.debug("    ====> `` if (result) then "DELETE" else "KEEP" ``");

    return result;
}

Boolean cleanSingleTenantCheServer() {
    try(oc = DefaultOpenShiftClient()) {
        String namespace = osioCheNamespace(oc);

        log.info("Cleaning single-tenant OpenShift resources in namespace `` namespace ``");

        void delete(HasMetadata resource) {
            oc.resource(resource).delete();
        }

        value resourceTypes = {
            oc.routes(),
            oc.services(),
            oc.extensions().deployments(),
            oc.services(),
            oc.extensions().replicaSets(),
            oc.configMaps()
        };

        resourceTypes
            .map((resType)=> resType.inNamespace(namespace).list().items)
            .flatMap((list) => { *list } )
            .filter(shouldBeDeleted)
            .each(delete);

        value cheServerPods = { *oc.pods().inNamespace(namespace).list().items }
        .filter(shouldBeDeleted);

        try {
            for(retry in [0:120]) {
                if (cheServerPods.empty) {
                    break;
                }
                Thread.sleep(1000);
            } else {
                // timeout reached
                log.error("Single-tenant Che server Pod could not be stopped, even after a 120 seconds timeout");
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