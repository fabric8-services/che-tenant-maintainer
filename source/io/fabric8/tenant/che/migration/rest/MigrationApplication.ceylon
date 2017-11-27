import javax.ws.rs {
    applicationPath,
    path,
    get,
    produces
}
import javax.ws.rs.core {
    Application,
    MediaType
}

applicationPath("/fabric8-tenant-che-migration")
shared class MigrationApplication() extends Application() {}

path("")
shared class WorkspacesEndpoint() {
    get
    produces {MediaType.textPlain}
    shared String help() =>
            """
               Single-tenant to multi-tenant migration tool
               """;
}

