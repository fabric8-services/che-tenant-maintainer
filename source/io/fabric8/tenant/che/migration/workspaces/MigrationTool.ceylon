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
import ceylon.uri {
    parse
}
import ceylon.json {
    JsonArray,
    parseJSON=parse,
    JsonValue=Value,
    JsonObject
}
import ceylon.http.client {
    ClientRequest=Request
}
import ceylon.http.common {
    post,
    get,
    Header
}
import ceylon.logging {
    Priority,
    infoPriority = info
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
    function authorization(String keycloakToken) => Header("Authorization", "Bearer ``keycloakToken``");

    shared Status run() {
        value endpointPath = "/wsmaster/api/workspace";
        value sourceEndpoint = sourceCheServer + endpointPath;
        value destinationEndpoint = destinationCheServer + endpointPath;
        

        log.debug(() => "Retrieving the list of workspaces from URL : `` sourceEndpoint `` ...");
        variable value response = ClientRequest {
            uri = parse(sourceEndpoint);
            method = get;
            initialHeaders = { authorization(keycloakToken) };
        }.execute();
        if (response.status != 200) {
            return Status.unexpectedErrorInSourceCheServer(response);
        }
        value responseContents = response.contents;
        log.debug(() => "    => `` responseContents ``");
        
        JsonValue workspaces;
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
            response = ClientRequest {
                uri = parse(destinationEndpoint);
                method = post;
                initialHeaders = { authorization(keycloakToken) };
                data = toCreate.string;
                dataContentType = "application/json";
            }.execute();
            
            switch(response.status)
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
        });

        if (nonempty createdWorkspaces) {
            log.info("Created workspaces: `` createdWorkspaces ``");
        } else {
            log.info("No workspaces created");
        }
        return status;
    }
}

