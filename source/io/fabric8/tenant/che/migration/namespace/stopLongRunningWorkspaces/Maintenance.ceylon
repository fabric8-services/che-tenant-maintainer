import ceylon.json {
    JsonObject
}
import ceylon.time {
    Period,
    Instant,
    systemTime
}
import fr.minibilles.cli {
    option
}
import io.fabric8.kubernetes.api.model {
    DoneableConfigMap,
    ConfigMap
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}
import io.fabric8.tenant.che.migration.namespace {
    ...
}
import io.fabric8.tenant.che.migration.workspaces {
    WorkspaceTool,
    WorkspaceStatus=Status,
    log
}

shared String name => Name.name;

named(`value name`)
shared class Maintenance(
    "
     API Url of the Che server that contains workspaces to clean.

     For example: `https://che.openshift.io/api`
     "
    option ("che-server")
    shared String cheServer,
    "
     Keycloak (OSIO) token of the user that will be migrated
     "
    option ("token")
    shared String keycloakToken,
    "
     Timeout to wait for the cleaning command completion (in seconds)
     Default value is 10 minutes
     "
    option ("command-timeout")
    shared Integer commandTimeout = environment.commandTimeout,
    "
     Dry run of stop workspaces task
     "
    option("dry-run")
    shared Boolean dryRun = false,
    "
     Max age, in hours, of running workspaces. Workspaces running for
     longer are stopped.
     Default value is 12 hours
     "
    option("max-age")
    shared Integer maxAge = 12,

    String identityId = "",
    String requestId = "",
    String jobRequestId = "",
    String osNamespace = environment.osNamespace else "",
    String osMasterUrl = environment.osMasterUrl else "",
    String osToken = environment.osToken else keycloakToken,
    Boolean debugLogs = environment.debugLogs)
        extends NamespaceMaintenance(
            identityId,
            requestId,
            jobRequestId,
            osNamespace,
            osMasterUrl,
            osToken,
            debugLogs,
            cheServiceAccountTokenManager.overrideConfig(identityId, keycloakToken)
){

    shared actual Status proceed() {
        value workspaceTool = WorkspaceTool(keycloakToken);
        value listWorkspaces = curry(workspaceTool.listWorkspaces)(cheServer);
        value isStopped = workspaceTool.isStopped;
        value stopWorkspace = curry(workspaceTool.stopWorkspace)(cheServer);

        try (oc = DefaultOpenShiftClient(osConfig)) {
            value namespace = osioCheNamespace(oc);

            KubernetesResource<ConfigMap,DoneableConfigMap>|Status lockResources = getLockResource(namespace);
            if (is Status lockResources) {
                return lockResources;
            }

            try {
                value workspaces = listWorkspaces();
                if (is WorkspaceStatus workspaces) {
                    return Status(1, workspaces.string);
                }
                log.debug(
                    () => "Cleaning long-running workspaces for namespace: ``namespace``.\n
                           Found running workspaces:
                           ``workspaces.map((w) => w.getObjectOrNull("config")?.getStringOrNull("name"))``");

                value workspacesToStop = workspaces.filter(not(isStopped)).filter(curry(isRunningFor)(maxAge));

                log.info(
                    () => "Found long running workspaces:
                           ``workspacesToStop.map((w) => w.getObjectOrNull("config")?.getStringOrNull("name"))``");

                if (!dryRun) {
                    workspacesToStop.each(stopWorkspace);
                } else {
                    log.info("Is dry run, doing nothing.");
                }
            } finally {
                lockResources.delete();
            }
        }
        return Status(1);
    }

    Boolean isRunningFor(Integer hours, JsonObject workspace) {
        value startTimeMillisField = workspace.getObjectOrNull("attributes")?.getStringOrNull("updated");
        if (!exists startTimeMillisField) {
            return false;
        }
        value startTimeMillis = Integer.parse(startTimeMillisField);
        if (is ParseException startTimeMillis) {
            return false;
        }

        value startTime = Instant(startTimeMillis);
        value maxDuration = Period().withHours(hours);
        value currentTime = systemTime.instant();
        log.debug(
            () => "Checking workspace '``workspace.getObjectOrNull("config")?.getStringOrNull("name") else "null"``'\n
                   Start time:              ``startTime``\n
                   Current time:            ``currentTime``\n
                   Start time plus timeout: ``startTime.plus(maxDuration)``
                   Result: stop workspace = ``startTime.plus(maxDuration) < currentTime``");
        return startTime.plus(maxDuration) < currentTime;
    }
}
