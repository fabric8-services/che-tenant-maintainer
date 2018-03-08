import fr.minibilles.cli {
    cliHelp=help
}

import javax.ws.rs.core {
    context,
    UriInfo
}
shared abstract class MigrationEndpoint<Migration>()
        given Migration satisfies NamespaceMigration {

    shared formal String endpointName;
    value endpointDesc => "../``endpointName`` endpoint";

    shared default Status post(String json) => doMigration<Migration> (endpointDesc, json);

    shared default Status get(context UriInfo info) => doMigration<Migration> (endpointDesc, [
        for (param in info.getQueryParameters(true).entrySet())
        "--``param.key``=``if (param.\ivalue.empty) then "" else param.\ivalue.get(0)``"
    ]);

    shared default String help() => cliHelp<Migration>(endpointDesc);
}
