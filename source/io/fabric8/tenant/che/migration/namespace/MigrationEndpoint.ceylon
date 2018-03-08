import fr.minibilles.cli {
    cliHelp=help
}

import javax.ws.rs.core {
    context,
    UriInfo,
    HttpHeaders {
        authorizationHeader = authorization
    }
}
import ceylon.json {
    JsonObject,
    JsonArray,
    parseJson = parse
}
shared abstract class MigrationEndpoint<Migration>()
        given Migration satisfies NamespaceMigration {
    value bearerPrefix = "Bearer ";
    value requestIdHeader = "X-Request-Id";
    value identityIdHeader = "X-Identity-Id";
    value namespaceHeader = "X-User-Namespace";

    shared formal String endpointName;
    value endpointDesc => "../``endpointName`` endpoint";

    shared default {<String->String>*} completeArguments(HttpHeaders headers) {
        return {
            if (exists requestId = headers.getHeaderString(requestIdHeader))
            then "request-id"->requestId else null,

            if (exists identityId = headers.getHeaderString(identityIdHeader))
            then "identity-id"->identityId else null,

            if (exists namespace = headers.getHeaderString(namespaceHeader))
            then "os-namespace"->namespace else null,

            if (exists auth = headers.getHeaderString(authorizationHeader),
                auth.startsWith(bearerPrefix))
            then "token" -> auth.spanFrom(bearerPrefix.size) else null,

            if (exists auth = headers.getHeaderString(authorizationHeader),
                auth.startsWith(bearerPrefix))
            then "os-token" -> auth.spanFrom(bearerPrefix.size) else null
        }.coalesced;
    }

    function overrideJson(HttpHeaders headers, JsonObject json) {
        json.putAll(completeArguments(headers));
        return json;
    }

    function parse(String json) =>
        if (is JsonObject parsed = parseJson(json))
        then parsed else JsonObject {};

    shared default Status post(context HttpHeaders headers, String json)
        => doMigration<Migration> (endpointDesc, overrideJson(headers,parse(json)));

    shared default Status get(context HttpHeaders headers, context UriInfo info) => doMigration<Migration> (endpointDesc,
        overrideJson(headers,JsonObject {
            for (param in info.getQueryParameters(true).entrySet())
            (param.key.string ->
            (if(param.\ivalue.empty)
            then true
            else if(param.\ivalue.size() > 1)
            then JsonArray({ for (v in param.\ivalue) v?.string })
            else param.\ivalue.get(0)?.string))
        }));

    shared default String help() => cliHelp<Migration>(endpointDesc);
}
