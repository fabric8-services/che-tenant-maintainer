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
import ceylon.json {
    JsonArray,
    JsonObject
}

path("workspaces")
shared class WorkspacesEndpoint() {

    post
    produces {MediaType.applicationJson}
    consumes {MediaType.applicationJson}
    shared Status post(String json) =>
            doMigration (json).first;

    get
    produces {MediaType.applicationJson}
    shared Status get(context UriInfo info) => doMigration (JsonObject {
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
    }.string).first;

    get
    path("help")
    produces {MediaType.textPlain}
    shared String help() {
        import fr.minibilles.cli { help }
        return help<MigrationTool>("../workspaces endpoint");
    }
}
