import fr.minibilles.cli {
    help
}

"Runs the `io.fabric8.tenant.che_workspace_migration` from the command line."
suppressWarnings("expressionTypeNothing")
shared void run() {

    value status = doMigration(*process.arguments);
    if (!status.successful()) {
        log.error(status.string);
    }
    process.exit(status.code);
}

String buildHelp() => help<MigrationTool>("java -jar `` `package`.name ``.jar");

