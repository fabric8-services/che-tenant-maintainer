import ceylon.logging {
    defaultPriority
}
import fr.minibilles.cli {
    Info,
    parseArguments
}
import ceylon.file {
    File,
    Nil
}
"Runs the migration from either command line or the REST endpoint"
shared Status doMigration(String* arguments) {
    logSettings.reset();

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
            return Status.wrongCommandLine(*errors);
        }
    } catch(Exception e) {
        return Status.unexpectedException(e);
    }
}
