import ceylon.file {
    parsePath,
    File,
    Nil
}
import ceylon.language.meta {
    type
}

import io.fabric8.tenant.che.migration.workspaces {
    log
}

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    value podMigrations = migrationTypes.map(withDefaultValues).coalesced;
    value migration = podMigrations.find((m)=> m.name == (environment.migration else ""));
    if (! exists migration) {
        log.error("MIGRATION environment variable should exist and have one of the following values: ``
        ",".join { for (m in podMigrations.filter((m) => ! type(m).declaration.annotated<MigrationFinished>())) m.name } ``");
        writeTerminationStatus(1);
        process.exit(0);
        return;
    }

    process.exit(migration.runAsPod());
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
