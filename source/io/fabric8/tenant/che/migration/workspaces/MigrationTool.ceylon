import fr.minibilles.cli {
    info,
    option,
    creator,
    additionalDoc
}
import ceylon.file {
    Path,
    parsePath
}
import ceylon.json {
    JsonArray,
    parseJSON=parse,
    JsonValue=Value,
    JsonObject
}
import ceylon.logging {
    Priority,
    infoPriority = info
}
import okhttp3 {
    Request { Http = Builder },
    OkHttpClient,
    RequestBody,
    MediaType { contentType = parse }
}
import java.util.concurrent {
    TimeUnit
}
import java.lang {
    Thread
}

String exitCodes => "Possible exit codes:\n\n" +
    "\n".join(Status.statuses.sort(byKey(increasing<Integer>))
    .map((code->description)=>"``  code``: ``description``")) +
    "\n";

"
 Fabric8 - Workspace Migration Tool
 
 This tool is used to migrate user workspaces
 from single-tenant Che to to Multi-tenant Che
 "
additionalDoc(`value exitCodes`)
info("Shows this help", "help", 'h')
class MigrationTool(

    "Url of the Che server that contains workspaces to migrate"
    option("source", 's')
    shared String sourceCheServer,

    "Url of the Che server that will receive migrated workspaces"
    option("destination", 'd')
    shared String destinationCheServer,
    
    "Keycloak token of the user that will be migrated"
    option("token", 't')
    shared String keycloakToken,
    
    "Ignore already existing workspaces (without throwing an error)"
    option("ignore-existing", 'i')
    shared Boolean ignoreExisting = false,
    
    "log file"
    option("log", 'l')
    creator(`function parsePath`)
    shared Path? logFile = null,
    
    "log level"
    option("log-level", 'v')
    shared Priority logLevel = infoPriority,
    
    "don't print any messages on standard outputs"
    option("qiet", 'q')
    shared Boolean quiet = false
    
) {
    value httpClient = OkHttpClient.Builder()
        .connectTimeout(2, TimeUnit.minutes)
        .readTimeout(2, TimeUnit.minutes)
        .build();

    function authorization(String keycloakToken) => ["Authorization", "Bearer ``keycloakToken``"];

    function send(Http builder) => httpClient.newCall(builder
        .header(*authorization(keycloakToken))
        .build()).execute();

    function get(String endpoint) => send(Http().get()
        .url(endpoint));

    function postJson(String endpoint, String content) => send(Http()
        .post(RequestBody.create(contentType("application/json"), content))
        .url(endpoint));

    shared Status run() {
        value endpointPath = "/wsmaster/api/workspace";
        value sourceEndpoint = sourceCheServer + endpointPath;
        value destinationEndpoint = destinationCheServer + endpointPath;

        log.debug(() => "Retrieving the list of workspaces from URL : `` sourceEndpoint `` ...");

        JsonValue workspaces;

        String? responseContents;
        value timeoutMinutes = 2;
        for(retry in 0:timeoutMinutes*60) {
            try (response = get(sourceEndpoint)) {
                switch(response.code())
                case(200) {
                    responseContents = response.body()?.string_method();
                    break;
                }
                case(503) {
                    log.debug("Single-tenant Che server not accessible (error 503). Retrying ...");
                    // Wait 1 second and retry
                    Thread.sleep(1000);
                }
                else {
                    return Status.unexpectedErrorInSourceCheServer(response);
                }
            }
        } else {
            log.error("Single-tenant Che server not accessible even after ``timeoutMinutes`` minutes at '`` sourceEndpoint ``'");
            return Status.sourceCheServerNotAccessible;
        }

        if (!exists responseContents) {
            return Status.invalidJsonInWorkspaceList("<null>");
        }
        if (responseContents.empty) {
            return Status.invalidJsonInWorkspaceList("");
        }

        log.debug(() => "    => `` responseContents ``");

        try {
            workspaces = parseJSON(responseContents);
        } catch(Exception e) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }
        if (! is JsonArray workspaces) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }

        value initialState = [Status.success, []];
        value [status, createdWorkspaces] = workspaces
                .narrow<JsonObject>()
                .map((workspace) => workspace.get("config"))
                .narrow<JsonObject>()
                .fold<[Status, [String*]]>(initialState)((currentState, toCreate) {
            
            value [status, alreadyCreated] = currentState;
            
            if (! status.successful()) {
                // Skip next workspaces since migration already failed
                return currentState;
            }
            
            value workspaceName = toCreate.getString("name");
            
            log.info(() => "Migration of workspace `` workspaceName ``");
            log.debug(() => "    Workspace configuration to create:\n`` toCreate.pretty ``");

            try (response = postJson(destinationEndpoint, toCreate.string)) {

                switch(response.code())
                case(201) {
                    log.info(() => "    => OK");
                    return [Status.success, [workspaceName, *alreadyCreated]];
                }
                case(403) {
                    return [Status.noRightToCreateNewWorkspace, alreadyCreated];
                }
                case(409) {
                    if (! ignoreExisting) {
                        return [Status.workspaceAlreadyExists(workspaceName), alreadyCreated];
                    }
                    log.info(() => "    => workspace already exists: Ignoring");
                    return [Status.success, alreadyCreated];
                }
                else {
                    return [Status.unexpectedErrorInDestinationCheServer(response), alreadyCreated];
                }
            }
        });

        if (nonempty createdWorkspaces) {
            log.info("Created workspaces: `` createdWorkspaces ``");
        } else {
            log.info("No workspaces created");
        }
        return status;
    }
}

