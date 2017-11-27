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
    try(oc = DefaultOpenShiftClient()) {
        value namespace = osioCheNamespace(oc);
        try {
            value cheServerDeploymentConfig =
                    oc.deploymentConfigs()
                        .inNamespace(namespace)
                        .withName(cheSingleTenantCheServerName);

            if (! cheServerDeploymentConfig?.get() exists) {
                log.info("Migration skipped (no more Che server)");
                return 0;
            }

            cheServerDeploymentConfig.scale(1, true);

            value cheServerPods => { *oc.pods().withLabel("deploymentconfig", "che").list().items};
            value podReady => if (exists ready = cheServerPods.first
                        ?.status?.containerStatuses?.get(0)
                        ?.ready?.booleanValue()) then ready else false;

            if (!podReady) {
                log.info("Starting the single-tenant Che server...");
                value timeoutMinutes = 5;
                for(retry in 0:timeoutMinutes*60) {
                    if(podReady) {
                        break;
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

        } catch(Exception e){
            log.error("Unexpected exception while migrating namespace `` namespace ``", e);
            return 1;
        }
    }

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
        log.error(status.string);
        return 1;
    }

    if (cleanupSingleTenant && ! cleanSingleTenantCheServer()) {
        return 1;
    }
    return 0;
}
