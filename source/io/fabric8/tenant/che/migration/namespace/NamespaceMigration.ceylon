import ceylon.file {
    File,
    parsePath,
    Nil
}
import ceylon.logging {
    debug,
    info
}

import fr.minibilles.cli {
    option
}

import io.fabric8.openshift.client {
    DefaultOpenShiftClient,
    OpenShiftClient,
    OpenShiftConfigBuilder,
    OpenShiftConfig
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings,
    log
}

import java.lang {
    JavaString=String
}

shared abstract class NamespaceMigration(

        "Identity ID of the user that will be migrated"
        option("identity-id", 'i')
        shared String identityId = "",

        "ID of the last migration request created by the tenant services"
        option("request-id", 'r')
        shared String requestId = "",

        "ID of the JOB migration request currently running"
        option("job-request-id", 'j')
        shared String jobRequestId = "",

        "OpenShift namespace in which actions will be applied"
        option("os-namespace", 'n')
        shared String osNamespace = environment.osNamespace else "",

        "OpenShift token that will be used to apply actions in the namespace"
        option("os-token", 'n')
        shared String osToken = environment.osToken else "",

        "debug"
        option("debug-logs", 'v')
        shared Boolean debugLogs = environment.debugLogs

        ) {

    value builder = OpenShiftConfigBuilder();
    if (!osNamespace.empty) {
        builder.withNamespace(osNamespace);
    }
    if (exists osMasterUrl = environment.osMasterUrl) {
        builder.withMasterUrl(osMasterUrl);
    }
    if (! osToken.empty) {
        builder.withOauthToken(osToken);
    }

    shared OpenShiftConfig osConfig = builder.build();

    shared formal String name;

    shared restricted(`module`) String osioCheNamespace(OpenShiftClient oc) =>
            if (!osNamespace.empty) then osNamespace else (oc.namespace else "default");

    shared formal Status migrate();

    shared Integer runAsPod() {
        logSettings.format = logToJson(()=>identityId, ()=>requestId);
        logSettings.reset(environment.debugLogs then debug else info);

        if (jobRequestId.empty) {
            log.error("JOB_REQUEST_ID doesn't exit. The migration should be started with a REQUEST_ID");
            writeTerminationStatus(1);
            return 0;
        }

        if (requestId.empty) {
            log.warn("REQUEST_ID doesn't exit. The config map is probably missing. Let's skip this migration without failing since it should be performed by another Job");
            writeTerminationStatus(0);
            return 0;
        }

        variable Integer exitCode;
        try {
            value status = migrate();
            exitCode = status.code;
            writeTerminationStatus(exitCode);
        } catch(Throwable e) {
            log.error("Unknown error during namespace migration", e);
        } finally {
            cleanMigrationResources(jobRequestId);
        }
        return 0;
    }

    void writeTerminationStatus(Integer exitCode) {
        value logFile = switch(resource = parsePath("/dev/termination-log").resource)
        case (is Nil) resource.createFile()
        case (is File) resource
        else null;
        if (exists logFile) {
            try (appender = logFile.Appender()) {
                appender.write(exitCode.string);
            }
        }
    }

    void cleanMigrationResources(String jobRequestId) {
        try(oc = DefaultOpenShiftClient(osConfig)) {
            if (exists configMap = oc.configMaps().inNamespace(osioCheNamespace(oc)).withName("migration").get(),
                exists reqId = configMap.data.get(JavaString("request-id"))?.string,
                reqId == jobRequestId) {
                oc.resource(configMap).delete();
            }
        } catch(Exception e) {
            log.warn("Exception while cleaning the migration Openshift resources", e);
        }
    }
}
