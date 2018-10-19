import ceylon.file {
    parsePath,
    File,
    Nil
}

import io.fabric8.tenant.che.migration.workspaces {
    log,
    logSettings
}
import java.nio.file {
    AccessDeniedException
}
import ceylon.language.meta.model {
    Class
}

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    
    value [requestedMaintenance, maintenance] = getMaintenance();
    value maintenanceInstance = withDefaultValues(maintenance);
    if (!exists maintenanceInstance) {
        logSettings.reset();
        log.error("The action `` requestedMaintenance `` cannot be instanciated with default values");
        writeTerminationStatus(1);
        process.exit(1);
        return;
    }
    
    process.exit(maintenanceInstance.runAsPod());
}

void writeTerminationStatus(Integer exitCode) {
    try {
        value logFile = switch(resource = parsePath("/dev/termination-log").resource)
        case (is Nil) resource.createFile()
        case (is File) resource
        else null;
        if (exists logFile) {
            try (appender = logFile.Appender()) {
                appender.write(exitCode.string);
            }
        }
    } catch(AccessDeniedException e) {}
}


suppressWarnings("expressionTypeNothing")
[String, Class<NamespaceMaintenance,Nothing>] getMaintenance() {
    logSettings.defaults();
    value requestedMaintenance = environment.maintenance;
    if (exists requestedMaintenance,
        exists maintenanceClass = maintenances[requestedMaintenance]) {
        return [requestedMaintenance, maintenanceClass];
    }
    
    logSettings.reset();
    log.error("MAINTENANCE environment variable should exist and have one of the following values: ``
        ",".join { for (name -> type in maintenances) if (! type.declaration.annotated<MaintenanceFinished>()) name } ``");
    writeTerminationStatus(1);
    process.exit(1);
    return nothing;
}

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void runAsSimpleProcess() {
    
    value [requestedMaintenance, maintenance] = getMaintenance();
    
    "Skip an additional wrongly added by the debugger in some cases"
    value arguments = process.arguments.skipWhile("--fully-export-maven-dependencies".equals).sequence();
    
    value status = `function doMaintenance`
            .apply<Status, [String, String[]]>(maintenance)
            .apply(requestedMaintenance, arguments);
    if (status.code != 0) {
        process.writeErrorLine(status.message);
        process.writeErrorLine(status.details);
    }
    process.exit(status.code);
}
