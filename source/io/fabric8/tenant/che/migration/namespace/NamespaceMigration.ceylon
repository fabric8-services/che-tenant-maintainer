import java.lang {
    JavaString=String
}
import ceylon.logging {
    debug,
    Priority,
    defaultPriority
}
import fr.minibilles.cli {
    option
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings,
    log
}
import ceylon.json {
    Object
}
import ceylon.file {
    File,
    parsePath,
    Nil
}
import ceylon.time {
    systemTime
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient,
    OpenShiftClient
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

        "debug"
        option("debug-logs", 'v')
        shared Boolean debugLogs = false

        ) {

    shared formal String name;

    shared Status migrate() {
        logSettings.reset();
        if (debugLogs) {
            defaultPriority = debug;
        }

        return doMigrate();
    }

    shared restricted(`module`) String osioCheNamespace(OpenShiftClient oc) =>
            environment.cheNamespace else oc.namespace;

    shared restricted(`module`) formal Status doMigrate();

    shared Integer runAsPod() {
        function logToJson(Priority p, String m, Throwable? t) {
            variable String stacktrace = "";
            if (exists t) {
                printStackTrace(t, (st) { stacktrace += st; });
            }
            return Object({
                "timestamp" -> systemTime.milliseconds(),
                "logger_name" -> "fabric8-tenant-che-migration",
                "message" -> m,
                "priority" -> p.string,
                if (! stacktrace.empty) then "stack_trace" -> stacktrace else null,
                if (!identityId.empty) then "identity_id" -> identityId else null,
                if (!requestId.empty) then "req_id" -> requestId else null
            }.coalesced).string;
        }
        logSettings.format = logToJson;

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
        try(oc = DefaultOpenShiftClient()) {
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
