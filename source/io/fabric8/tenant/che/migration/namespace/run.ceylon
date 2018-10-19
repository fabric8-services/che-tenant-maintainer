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

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    logSettings.defaults();
    value requestedMaintenance = environment.maintenance;
    
    value maintenance = if (exists requestedMaintenance)
    then maintenances[requestedMaintenance]
    else null;
    
    if (! exists maintenance) {
        logSettings.reset();
        log.error("MAINTENANCE environment variable should exist and have one of the following values: ``
        ",".join { for (name -> type in maintenances) if (! type.declaration.annotated<MaintenanceFinished>()) name } ``");
        writeTerminationStatus(1);
        process.exit(1);
        return;
    }

    assert(exists requestedMaintenance);
    
    value migrationInstance = withDefaultValues(maintenance);
    if (!exists migrationInstance) {
        logSettings.reset();
        log.error("The action `` requestedMaintenance `` cannot be instanciated with default values");
        writeTerminationStatus(1);
        process.exit(1);
        return;
    }
    
    process.exit(migrationInstance.runAsPod());
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
