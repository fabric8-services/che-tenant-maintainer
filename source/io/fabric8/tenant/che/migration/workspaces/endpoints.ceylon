import javax.ws.rs {
    path,
    get,
    produces
}
import javax.ws.rs.core {
    MediaType,
    context,
    UriInfo
}

path("workspaces")
shared class WorkspacesEndpoint() {
    get
    path("migrate")
    produces {MediaType.applicationJson}
    shared Status migrate(context UriInfo info) => doMigration (*[
        for (param in info.getQueryParameters(true).entrySet())
        "--``param.key``=``if (param.\ivalue.empty) then "" else param.\ivalue.get(0)``"
    ]);

    get
    path("help")
    produces {MediaType.textPlain}
    shared String help() => buildHelp();
}
