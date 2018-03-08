import io.fabric8.tenant.che.migration.workspaces {
    log
}
import fr.minibilles.cli {
    Info,
    parseArguments,
    parseJson,
    help
}
import java.lang {
    System
}

Status doMigration<Migration>(String programName, [String*]|String argumentsOrJson)
    given Migration satisfies NamespaceMigration {

    System.setProperty("kubernetes.auth.tryKubeConfig", "true");
    try {
        value parsingResult = switch (argumentsOrJson)
        case (is String) parseJson<Migration>(argumentsOrJson.string)
        else parseArguments<Migration>(argumentsOrJson);

        switch (parsingResult)
        case (is Info) {
            return Status(0, help<Migration>(programName));
        }
        case (is Migration) {
            value migrator = parsingResult;
            return migrator.migrate();
        }
        else {
            value errors = parsingResult;
            return Status(1, "Wrong command line:\n`` "\n - ".join { errors } ``");
        }
    } catch (Exception e) {
        log.error("Unexpected exception", e);
        return Status(1, "Unexpected exception:\n`` e ``");
    }
}
