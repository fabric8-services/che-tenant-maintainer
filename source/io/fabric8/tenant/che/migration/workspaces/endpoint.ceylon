import javax.ws.rs {
    applicationPath,
    path,
    get,
    produces
}
import javax.ws.rs.core {
    Application,
    MediaType,
    context,
    UriInfo
}

applicationPath("/fabric8-workspace-migration")
shared class MigrationApplication() extends Application() {}

path("run")
shared class RunEndpoint() {
    get
    produces {MediaType.applicationJson}
    shared Status migrate(context UriInfo info) => doMigration (*[
        for (param in info.getQueryParameters(true).entrySet())
        "--``param.key``=``if (param.\ivalue.empty) then "" else param.\ivalue.get(0)``"
    ]);
}

path("help")
shared class HelpEndpoint() {
    get
    produces {MediaType.textPlain}
    shared String migrate() => buildHelp();
}
