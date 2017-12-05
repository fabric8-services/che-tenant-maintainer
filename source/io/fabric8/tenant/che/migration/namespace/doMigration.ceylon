import io.fabric8.tenant.che.migration.workspaces {
    log,
    migrateWorkspaces=doMigration,
    logSettings
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import ceylon.logging {
    debug,
    defaultPriority
}
import java.lang {
    Thread
}
import io.fabric8.openshift.client.dsl {
    DeployableScalableResource
}
import io.fabric8.openshift.api.model {
    DeploymentConfig,
    DoneableDeploymentConfig
}

Integer doMigration(String? debugLogsParam = null, String? cleanupSingleTenantParam = null) {
    logSettings.reset();
    value debugLogs = (debugLogsParam else env.debugLogs else "false").lowercased == "true";
    if (debugLogs) {
        defaultPriority = debug;
    }
    value cleanupSingleTenant = (cleanupSingleTenantParam else env.cleanupSingleTenant else "false").lowercased == "true" ;

    value keycloakToken = env.osioToken;
    value destinationCheServer = env.multiTenantCheServer;
    String singleTenantCheServer;

    alias DeploymentConfigResource => DeployableScalableResource<DeploymentConfig,DoneableDeploymentConfig>;

    DeploymentConfigResource getCheServerDeploymentConfig(DefaultOpenShiftClient oc, String namespace) =>
            oc.deploymentConfigs()
                .inNamespace(namespace)
                .withName(cheSingleTenantCheServerName);

    function serverCleaned(DeploymentConfigResource? deploymentConfig) => ! deploymentConfig?.get() exists;

    try(oc = DefaultOpenShiftClient()) {
        value namespace = osioCheNamespace(oc);

        value lockResources = oc.configMaps().inNamespace(namespace).withName("migration-lock");
        if(lockResources.get() exists) {
            log.info("A previous migration Job is already running. Waiting for it to finish...");
        }

        variable value timeoutMinutes = 10;
        for(retry in 0:timeoutMinutes*60) {
            if(! lockResources.get() exists) {
                try {
                    if (lockResources.createNew().withNewMetadata().withName("migration-lock").endMetadata().done() exists) {
                        break;
                    }
                } catch(Exception e) {
                    log.warn("Exception when trying to create the lock config map", e);
                }
            }
            Thread.sleep(1000);
        } else {
            log.error("The migration lock is still owned, even after a ``timeoutMinutes`` minutes in namespace '`` namespace ``'
                       It might be necessary to remove the 'migration-lock' config map manually.");
            return 1;
        }

        try {
            value cheServerDeploymentConfig = getCheServerDeploymentConfig(oc, namespace);

            value shouldSkipMigration => serverCleaned(cheServerDeploymentConfig);

            if (shouldSkipMigration) {
                log.info("Migration skipped (no more Che server)");
                return 0;
            }

            try {
                cheServerDeploymentConfig.scale(1, true);
            } catch(Exception e) {
                if (shouldSkipMigration) {
                    log.info("Migration skipped (no more Che server)");
                    return 0;
                }
                throw e;
            }

            value cheServerPods => { *oc.pods().withLabel("deploymentconfig", "che").list().items};
            value podReady => if (exists ready = cheServerPods.first
                        ?.status?.containerStatuses?.get(0)
                        ?.ready?.booleanValue()) then ready else false;

            if (!podReady) {
                log.info("Starting the single-tenant Che server...");
                timeoutMinutes = 5;
                for(retry in 0:timeoutMinutes*60) {
                    if(podReady) {
                        break;
                    }
                    if (shouldSkipMigration) {
                        log.info("Migration skipped (no more Che server)");
                        return 0;
                    }
                    Thread.sleep(1000);
                } else {
                    log.error("Single-tenant Che server could not be started even after a ``timeoutMinutes`` minutes in namespace '`` namespace ``'");
                    return 1;
                }
                log.info("... Started");
            }

            value cheServerRouteOperation = oc.routes().withName(cheSingleTenantCheServerRoute);
            value cheServerRoute = cheServerRouteOperation?.get();
            if (! exists cheServerRoute) {
                if (shouldSkipMigration) {
                    log.info("Migration skipped (no more Che server)");
                    return 0;
                }
                // user tenant is not in a consistent state.
                // We should reset his environment in single-tenant mode
                // before retrying the migration.
                log.error("Single-tenant Che namespace '`` namespace ``' is in an inconsistent state ('che' deployment without a 'che' route).
                           You should switch back to single-tenant mode, update your tenant and retry");
                return 1;
            }

            value spec= cheServerRoute.spec;
            singleTenantCheServer =
                    "http`` if (spec.tls exists) then "s" else "" ``://``spec.host``";

            value args = {
                "source"-> singleTenantCheServer,
                "token"-> keycloakToken,
                "destination"-> destinationCheServer,
                "ignore-existing"-> "true",
                if(debugLogs) "log-level" -> "DEBUG"
            }.map((name -> val)=> if (exists val) then "--``name``=``val``" else null)
                .coalesced
                .sequence();

            log.debug("Calling workspace migration utility with the following arguments:\n`` args ``");

            value status = migrateWorkspaces(*args);
            if (!status.successful()) {
                if (serverCleaned {
                    value deploymentConfig {
                        return getCheServerDeploymentConfig(oc, namespace);
                    }
                }) {
                    log.info("Migration skipped because it was probably already done by a previous migration Job");
                    return 0;
                }
                log.error(status.string);
                return 1;
            }

            if (cleanupSingleTenant && ! cleanSingleTenantCheServer()) {
                return 1;
            }
        } catch(Exception e){
            log.error("Unexpected exception while migrating namespace `` namespace ``", e);
            return 1;
        } finally {
            lockResources.delete();
        }
    }
    return 0;
}
