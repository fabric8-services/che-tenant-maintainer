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
    migrations,
    MigrationFinished,
    logToJson,
    logIds
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings,
    log
}
import org.jboss.logging {
    Logger
}

applicationPath("/")
shared class MigrationApplication() extends Application() {
    value logger = Logger.getLogger("MigrationApplication");
    logSettings.format = logToJson(logIds.identity, logIds.request);
    logSettings.appender = (String message) => logger.info(message);
    log.info(()=>"Registered Migration application at the following web context: '/'");
}

path("")
shared class MainEndpoint() {

    get
    produces {MediaType.textPlain}
    shared String help() =>
            "Fabric8 migration and maintenance tool for User Che tenants.

             Available endpoints: `` ", ".join { for (name -> type in migrations) if (! type.declaration.annotated<MigrationFinished>()) name } ``

             For each endpoint, you can get help by requesting the './help' subpath.";
}

