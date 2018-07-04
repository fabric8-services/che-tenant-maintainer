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
    MigrationEndpoint,
    Status,
    environment
}
import io.fabric8.tenant.che.migration.workspaces {
    log
}
import java.lang {
    Types {
        classForType
    }
}

path(Name.name)
shared class Endpoint() extends MigrationEndpoint<Maintenance>() {

    endpointName => Name.name;
    log.info(()=>"Starting endpoint: ``endpointName`` from class `` classForType<Endpoint>() ``");

    completeArguments(HttpHeaders headers) => super.completeArguments(headers).chain {
        if (exists cheServer = environment.cheDestinationServer)
        then "che-server" -> cheServer else null
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

