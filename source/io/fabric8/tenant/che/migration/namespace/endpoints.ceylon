import javax.ws.rs {
    path,
    get,
    produces,
    queryParam
}
import javax.ws.rs.core {
    MediaType
}

path("namespace")
shared class NamespaceEndpoint() {
    get
    produces {MediaType.applicationJson}
    shared Integer migrate(queryParam("debug") String? debug = null) {
        return doMigration(debug);
    }

    get
    path("help")
    produces {MediaType.textPlain}
    shared String help()
        => """The `../workspaces` endpoint will try to fully migrate
              the current OSIO namespace to multi-tenant Che

              This application should be deployed in the user OSIO
              Che namespace""";
}

