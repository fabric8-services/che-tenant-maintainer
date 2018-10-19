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
    UriInfo,
    HttpHeaders
}
import io.fabric8.tenant.che.migration.namespace {
    MaintenanceEndpoint,
    Status,
    environment
}

path(Name.name)
shared class Endpoint() extends MaintenanceEndpoint<Migration>() {

    endpointName => Name.name;

    completeArguments(HttpHeaders headers) => super.completeArguments(headers).chain {
        if (exists source = environment.multiTenantCheServer)
        then "source" -> source else null,

        if (exists destination = environment.cheDestinationServer)
        then "destination" -> destination else null
    }.coalesced;

    post
    produces {MediaType.applicationJson}
    consumes {MediaType.applicationJson}
    shared actual Status post(context HttpHeaders headers, String json) => super.post(headers, json);

    get
    produces {MediaType.applicationJson}
    shared actual Status get(context HttpHeaders headers, context UriInfo info) => super.get(headers, info);

    get
    path("help")
    produces {MediaType.textPlain}
    shared actual String help() => super.help();
}

