import ceylon.file {
    Nil,
    File
}
import ceylon.http.client {
    ClientResponse=Response
}
import ceylon.http.common {
    Header
}
import ceylon.logging {
    addLogWriter,
    writeSimpleLog,
    defaultPriority
}

import fr.minibilles.cli {
    parseArguments,
    help,
    Info
}


String buildHelp() => help<MigrationTool>("java -jar `` `package`.name ``.jar");

"Run the module `io.fabric8.tenant.che_workspace_migration`."
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
            addLogWriter(writeSimpleLog);
            value errors = parsingResult;
            status = Status.wrongCommandLine(*errors);
            log.error(status.string);
            return status;
        }
    } catch(Exception e) {
        addLogWriter(writeSimpleLog);
        log.error("Unexpected exception: ", e);
        return Status.unexpectedException(e);
    }
}

suppressWarnings("expressionTypeNothing")
shared void run() => process.exit(doMigration(*process.arguments).code);

String dumpResponse(ClientResponse response) => "``response.status`` - `` response.contents ``";

Header authorization(String keycloakToken) => Header("Authorization", "Bearer ``keycloakToken``");
