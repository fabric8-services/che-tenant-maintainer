import ceylon.logging {
    debug,
    defaultPriority
}

import fr.minibilles.cli {
    option
}

import io.fabric8.kubernetes.api.model {
    HasMetadata
}
import io.fabric8.openshift.api.model {
    DeploymentConfig,
    DoneableDeploymentConfig
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import io.fabric8.openshift.client.dsl {
    DeployableScalableResource
}
import io.fabric8.tenant.che.migration.namespace {
    ...
}
import io.fabric8.tenant.che.migration.workspaces {
    log,
    migrateWorkspaces=doMigration
}

import java.lang {
    Thread,
    InterruptedException
}

shared Migration withDefaultValues() => Migration(
    environment.multiTenantCheServer else "",
    environment.osioToken else "",
    (environment.cleanupSingleTenant else "false").lowercased == "true",
    environment.identityId else "",
    environment.requestId else "",
    environment.jobRequestId else "",
    environment.osNamespace else "",
    environment.osMasterUrl else "",
    environment.osToken else "",
    environment.debugLogs
);

shared String name => Name.name;

"This utility will try to fully migrate the current
 single-tenant OSIO namespace to multi-tenant Che

 This application should be deployed in the user OSIO
 Che namespace"
maintenanceFinished
named(`value name`)
shared class Migration(

        "Url of the multi-tenant Che server that will receive migrated workspaces"
        option("destination", 'd')
        shared String destinationCheServer,

        "Keycloak token of the user that will be migrated"
        option("token", 't')
        shared String keycloakToken,

        "Cleanup single-tenant resources"
        option("cleanup", 'c')
        shared Boolean cleanupSingleTenant = false,

        String identityId = "",
        String requestId = "",
        String jobRequestId = "",
        String namespace = environment.osNamespace else "",
        String osMasterUrl = environment.osMasterUrl else "",
        String osToken = environment.osToken else "",
        Boolean debugLogs = false

        ) extends NamespaceMaintenance(identityId, requestId, jobRequestId, namespace, osMasterUrl, osToken, debugLogs) {

    value cheSingleTenantCheServerName="che";
    value cheSingleTenantCheServerRoute="che";

    shared actual Status proceed() {
        value keycloakToken = environment.osioToken;
        String singleTenantCheServer;

        alias DeploymentConfigResource => DeployableScalableResource<DeploymentConfig,DoneableDeploymentConfig>;

        DeploymentConfigResource getCheServerDeploymentConfig(DefaultOpenShiftClient oc, String namespace) =>
                oc.deploymentConfigs()
                    .inNamespace(namespace)
                    .withName(cheSingleTenantCheServerName);

        function serverCleaned(DeploymentConfigResource? deploymentConfig) => ! deploymentConfig?.get() exists;

        try(oc = DefaultOpenShiftClient(osConfig)) {
            value namespace = osioCheNamespace(oc);

            value lockResources = getLockResource(namespace);
            if (is Status lockResources) {
                return lockResources;
            }

            try {
                value cheServerDeploymentConfig = getCheServerDeploymentConfig(oc, namespace);

                value shouldSkipMigration => serverCleaned(cheServerDeploymentConfig);

                if (shouldSkipMigration) {
                    value message = "Migration skipped (no more Che server)";
                    log.info(message);
                    return Status(0, message);
                }

                try {
                    cheServerDeploymentConfig.scale(1, true);
                } catch(Exception e) {
                    if (shouldSkipMigration) {
                        value message = "Migration skipped (no more Che server)";
                        log.info(message);
                        return Status(0, message);
                    }
                    throw e;
                }

                value cheServerPods => { *oc.pods().withLabel("deploymentconfig", "che").list().items};
                value podReady =>
                        if (exists statuses = cheServerPods.first?.status?.containerStatuses,
                            ! statuses.empty,
                            exists ready = statuses.get(0)?.ready?.booleanValue())
                        then ready
                        else false;

                if (!podReady) {
                    log.info("Starting the single-tenant Che server...");
                    value timeoutMinutes = 5;
                    for(retry in 0:timeoutMinutes*60) {
                        if(podReady) {
                            break;
                        }
                        if (shouldSkipMigration) {
                            value message = "Migration skipped (no more Che server)";
                            log.info(message);
                            return Status(0, message);
                        }
                        Thread.sleep(1000);
                    } else {
                        value message = "Single-tenant Che server could not be started even after a ``timeoutMinutes`` minutes in namespace '`` namespace ``'";
                        log.error(message);
                        return Status(1, message);
                    }
                    log.info("... Started");
                }

                value cheServerRouteOperation = oc.routes().withName(cheSingleTenantCheServerRoute);
                value cheServerRoute = cheServerRouteOperation?.get();
                if (! exists cheServerRoute) {
                    if (shouldSkipMigration) {
                        value message = "Migration skipped (no more Che server)";
                        log.info(message);
                        return Status(0, message);
                    }
                    // user tenant is not in a consistent state.
                    // We should reset his environment in single-tenant mode
                    // before retrying the migration.
                    value message = "Single-tenant Che namespace '`` namespace ``' is in an inconsistent state ('che' deployment without a 'che' route).
                                     You should switch back to single-tenant mode, update your tenant and retry";
                    log.error(message);
                    return Status(1, message);
                }

                value spec= cheServerRoute.spec;
                singleTenantCheServer =
                        "http`` if (spec.tls exists) then "s" else "" ``://``spec.host``";

                value args = {
                    "source"-> singleTenantCheServer,
                    "token"-> keycloakToken,
                    "destination"-> destinationCheServer,
                    "ignore-existing"-> "true",
                    if(defaultPriority == debug) "log-level" -> "DEBUG"
                }.map((name -> val)=> if (exists val) then "--``name``=``val``" else null)
                    .coalesced
                    .sequence();

                log.debug("Calling workspace migration utility with the following arguments:\n`` args ``");

                value status = migrateWorkspaces(args).first;
                if (!status.successful()) {
                    if (serverCleaned {
                        value deploymentConfig {
                            return getCheServerDeploymentConfig(oc, namespace);
                        }
                    }) {
                        value message = "Migration skipped because it was probably already done by a previous migration Job";
                        log.info(message);
                        return Status(0, message);
                    }
                    log.error(status.string);
                    return Status(1, status.string);
                }

                if (cleanupSingleTenant && ! cleanSingleTenantCheServer()) {
                    return Status(1, "Single-tenant resource cleaning failed");
                }
            } catch(Exception e){
                value message = "Unexpected exception while migrating namespace `` namespace ``";
                log.error(message, e);
                return Status(1, message);
            } finally {
                lockResources.delete();
            }
        }
        return Status(0, "Migration successful");
    }

    Boolean cleanSingleTenantCheServer() {
        try(oc = DefaultOpenShiftClient(osConfig)) {
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
                oc.deploymentConfigs(),
                oc.services(),
                oc.extensions().deployments(),
                oc.extensions().replicaSets(),
                oc.configMaps(),
                oc.routes()
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
}
