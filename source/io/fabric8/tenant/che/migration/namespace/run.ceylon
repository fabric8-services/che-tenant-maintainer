import ceylon.json {
    Object
}
import ceylon.logging {
    Priority
}
import ceylon.time {
    systemTime
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings
}

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    value identityId = env.identityId;
    value requestId = env.requestId;

    function logToJson(Priority p, String m, Throwable? t) {
        variable String? stacktrace = null;
        if (exists t) {
            printStackTrace(t, (st) { stacktrace = st; });
        }
        return Object({
            "timestamp" -> systemTime.milliseconds(),
            "logger_name" -> "fabric8-tenant-che-migration",
            "message" -> m,
            "priority" -> p.string,
            if (exists st = stacktrace) then "stack_trace" -> st else null,
            if (exists id = identityId) then "identity_id" -> id else null,
            if (exists id = requestId) then "req_id" -> id else null
        }.coalesced).string;
    }
    logSettings.format = logToJson;

    variable Integer exitCode;
    try {
        exitCode = doMigration();
    } catch(Exception e) {
        e.printStackTrace();
        exitCode = 1;
    } finally {
        cleanMigrationResources();
    }
    process.exit(exitCode);
}
