import ceylon.file {
    Nil,
    File
}
import ceylon.logging {
    defaultPriority
}

import fr.minibilles.cli {
    parseArguments,
    help,
    Info
}

"Runs the `io.fabric8.tenant.che_workspace_migration` from the command line."
suppressWarnings("expressionTypeNothing")
shared void run() => process.exit(doMigration(*process.arguments).code);

"Runs the migration from either command line or the REST endpoint"
Status doMigration(String* arguments) {
    logSettings.reset();
    
    Status status;
    try {
        switch(parsingResult = parseArguments<MigrationTool>(arguments))
        case(is Info) {
            print(buildHelp());
            return Status.buildHelpShown;
        }
        case(is MigrationTool) {
            value migrator = parsingResult;
            defaultPriority = migrator.logLevel;
            if (exists logPath = migrator.logFile) {
                File logFile;
                switch (resource = logPath.resource)
                case (is Nil) {
                    logFile = resource.createFile();
                }
                case (is File) {
                    logFile = resource;
                }
                else {
                    return Status.logFileCannotBeWritten(logPath);
                }

                logSettings.file = logFile;
            }
            
            logSettings.quiet = migrator.quiet;
            
            return migrator.run();
        }
        else {
            value errors = parsingResult;
            status = Status.wrongCommandLine(*errors);
            log.error(status.string);
            return status;
        }
    } catch(Exception e) {
        log.error("Unexpected exception: ", e);
        return Status.unexpectedException(e);
    }
}

String buildHelp() => help<MigrationTool>("java -jar `` `package`.name ``.jar");

