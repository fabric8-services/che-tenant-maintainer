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
import io.fabric8.tenant.che.migration.workspaces {
    log
}

import java.lang {
    JavaString=String
}
import java.util {
    JavaMap=Map
}

Map<String, String> toCeylon(JavaMap<JavaString, JavaString>? javaMap) =>
        if(exists javaMap)
        then map {
            for (e in javaMap.entrySet())
                if(exists key = e.key, exists item = e.\ivalue)
                    key.string -> item.string
        }
        else map {};

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
