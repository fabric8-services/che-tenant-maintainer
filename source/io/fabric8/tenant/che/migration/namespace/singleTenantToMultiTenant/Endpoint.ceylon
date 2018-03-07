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
import io.fabric8.tenant.che.migration.namespace {
    MigrationEndpoint,
    Status
}


path(Name.name)
shared class Endpoint() extends MigrationEndpoint<Migration>() {

    endpointName = Name.name;

    post
    produces {MediaType.applicationJson}
    consumes {MediaType.applicationJson}
    shared actual Status post(String json) => super.post(json);

    get
    produces {MediaType.applicationJson}
    shared actual Status get(context UriInfo info) => super.get(info);

    get
    path("help")
    produces {MediaType.textPlain}
    shared actual String help() => super.help();
}
