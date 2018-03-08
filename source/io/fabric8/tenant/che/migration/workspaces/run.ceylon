import fr.minibilles.cli {
    help
}

"Runs the `io.fabric8.tenant.che.migration.workspaces` module from the command line."
suppressWarnings("expressionTypeNothing")
shared void run() {

    value status = doMigration(process.arguments).first;
    if (!status.successful()) {
        log.error(status.string);
    }
    process.exit(status.code);
}

String buildHelp() => help<MigrationTool>("./ceylonb run `` `module`.name ``");

