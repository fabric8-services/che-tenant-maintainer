import javax.ws.rs {
    path,
    get,
    produces
}
import javax.ws.rs.core {
    MediaType
}

path("namespace")
shared class NamespaceEndpoint() {
    get
    path("migrate")
    produces {MediaType.applicationJson}
    shared Integer migrate(String? debug = null) {
        try {
            return doMigration(debug);
        } finally {
            cleanMigrationResources();
        }
    }

    get
    path("help")
    produces {MediaType.textPlain}
    shared String help()
        => """The `/migrate` endpoint will try to fully migrate
              the current OSIO namespace to multi-tenant Che

              This application should be deployed in the user OSIO
              Che namespace""";
}

