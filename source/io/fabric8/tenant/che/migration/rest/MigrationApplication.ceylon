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
import io.fabric8.tenant.che.migration.namespace {
    migrationNames
}

applicationPath("/")
shared class MigrationApplication() extends Application() {}

path("")
shared class MainEndpoint() {
    get
    produces {MediaType.textPlain}
    shared String help() =>
            "Fabric8 migration and maintenance tool for User Che tenants.

             Available endpoints: `` ", ".join(migrationNames) ``

             For each endpoint, you can get help by requesting the './help' subpath.";
}

