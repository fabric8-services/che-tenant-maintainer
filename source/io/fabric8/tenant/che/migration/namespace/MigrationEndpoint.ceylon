import ceylon.json {
    JsonObject,
    JsonArray,
    parseJson=parse
}

import fr.minibilles.cli {
    cliHelp=help
}

import io.fabric8.tenant.che.migration.workspaces {
    logSettings
}

import javax.ws.rs.core {
    context,
    UriInfo,
    HttpHeaders {
        authorizationHeader=authorization
    }
}

shared abstract class MigrationEndpoint<Migration>()
        given Migration satisfies NamespaceMigration {
    value bearerPrefix = "Bearer ";
    value requestIdHeader = "X-Request-Id";
    value identityIdHeader = "X-Identity-Id";
    value namespaceHeader = "X-User-Namespace";

    logSettings.format = logToJson(logIds.identity, logIds.request);

    shared formal String endpointName;
    value endpointDesc => "../``endpointName`` endpoint";

    shared default {<String->String>*} completeArguments(HttpHeaders headers) {
        value requestId = headers.getHeaderString(requestIdHeader);
        value identityId = headers.getHeaderString(identityIdHeader);
        logIds.setup(identityId, requestId);
        return {
            if (exists requestId)
            then "request-id"->requestId else null,

            if (exists identityId)
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

    shared default Status post(context HttpHeaders headers, String json) => logIds.resetAfter(()=>
         doMigration<Migration> (endpointDesc, overrideJson(headers,parse(json))));

    shared default Status get(context HttpHeaders headers, context UriInfo info) => logIds.resetAfter(()=>
        doMigration<Migration> (endpointDesc,
        overrideJson(headers,JsonObject {
            for (param in info.getQueryParameters(true).entrySet())
            (param.key.string ->
            (if(param.\ivalue.empty)
            then true
            else
                if(param.\ivalue.size() > 1)
                then JsonArray({ for (v in param.\ivalue) v?.string })
                else
                    if (exists str = param.\ivalue.get(0)?.string)
                    then
                        if(is Boolean bool = Boolean.parse(str))
                        then bool
                        else str
                    else null ))
        })));

    shared default String help() => cliHelp<Migration>(endpointDesc);
}
