import io.fabric8.tenant.che.migration.workspaces {
    log,
    logSettings
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
import ceylon.json {
    JsonObject
}
import ceylon.logging {
    debug,
    info
}

Status doMigration<Migration>(String programName, [String*]|JsonObject argumentsOrJson)
    given Migration satisfies NamespaceMigration {

    logSettings.reset(environment.debugLogs then debug else info);

    System.setProperty("kubernetes.auth.tryKubeConfig", "true");
    log.debug(() => "Applying migration '`` programName ``' with the following parameters: `` argumentsOrJson ``");
    try {
        value parsingResult = switch (argumentsOrJson)
        case (is JsonObject) parseJson<Migration>(argumentsOrJson.string)
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
            return Status(1, "Wrong parameters:\n`` "\n - ".join { errors } ``");
        }
    } catch (Exception e) {
        log.error("Unexpected exception", e);
        return Status(1, "Unexpected exception:\n`` e ``");
    }
}
