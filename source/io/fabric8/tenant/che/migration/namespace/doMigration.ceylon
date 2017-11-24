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
                        .withName(cheSingleTenantCheServerName).get();

            if (! exists cheServerDeploymentConfig) {
                log.info("Migration skipped (no more Che server)");
                return 0;
            }

            value cheServerRoute = { *oc.routes().list().items }
                .find((route) => route.metadata.name == cheSingleTenantCheServerRoute);

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

    log.info("Calling workspace migration utility with the following arguments:\n`` args ``");

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
