import javax.ws.rs {
    path,
    get,
    produces,
    consumes,
    post
}
import javax.ws.rs.core {
    MediaType,
    context,
    UriInfo
}

path("workspaces")
shared class WorkspacesEndpoint() {
    post
    produces {MediaType.applicationJson}
    consumes {MediaType.applicationJson}
    shared Status post(String json) =>
            doMigration (json).first;

    get
    produces {MediaType.applicationJson}
    shared Status get(context UriInfo info) => doMigration ([
        for (param in info.getQueryParameters(true).entrySet())
        "--``param.key``=``if (param.\ivalue.empty) then "" else param.\ivalue.get(0)``"
    ]).first;

    get
    path("help")
    produces {MediaType.textPlain}
    shared String help() {
        import fr.minibilles.cli { help }
        return help<MigrationTool>("../workspaces endpoint");
    }
}
