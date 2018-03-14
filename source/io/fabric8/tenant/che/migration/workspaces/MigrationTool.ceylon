import ceylon.regex {
    regex,
    RegexException
}
import fr.minibilles.cli {
    info,
    option,
    creator,
    additionalDoc,
    parameters
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
import java.net {
    SocketTimeoutException
}

String exitCodes =>
    """replace :
       
       regular expressions to apply to
       the workspace Json definition
       with the form `/<regexp>/<replacement>/[g]`.
       
       *Remarks:*
       
           - The `/` separator character can be replaced by any other
       character not used in the `<regexp>` and `<replacement>`.
           - The `g` character can be suffixed to apply the regular
       expression *globally*, and not only once.
       
       *Examples:*

           - `/("recipe":\{)"location"/$1"content"/`
           - `/"agents"(:\[[^]]+)\]/"installers"$1,"new-installer"]/`
    
       Possible exit codes:
       
       """ +
    "\n".join(Status.statuses.sort(byKey(increasing<Integer>))
    .map((code->description)=>"``  code``: ``description``")) +
    "\n";

"
 Fabric8 - Workspace Migration Tool
 
 This tool is used to migrate user workspaces
 from one source Che server to a destination Che server
 "
additionalDoc(`value exitCodes`)
parameters({`value replace`})
info("Shows this help", "help", 'h')
shared class MigrationTool(

    "Api endpoint Url of the Che server that contains workspaces to migrate"
    option("source", 's')
    shared String sourceCheServer,

    "Api endpoint Url of the Che server that will receive migrated workspaces"
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
    shared Boolean quiet = false,

    """regular expressions to apply to the workspace Json definition
       with the form `/<regexp>/<replacement>/[g]`.
       
       *Remarks:*
       
           - The `/` separator character can be replaced by any other
       character not used in the `<regexp>` and `<replacement>`.
           - The `g` character can be suffixed to apply the regular
       expression *globally*, and not only once.
       
       *Examples:*

           - `/("recipe":\{)"location"/$1"content"/`
           - `/"agents"(:\[[^]]+)\]/"installers"$1,"new-installer"]/`
       """
    shared [String*] replace = []
) {
    function buildRegexp(variable String param) {
        variable Boolean global = false;
        value sepChar = param.first;
        if (!exists sepChar) {
            return null;
        }

        assert(exists end = param.last);
        if (end != sepChar) {
            if(end != 'g') {
                return null;
            }
            global = true;
            param = param.measure(0, param.size - 1);
        }

        value middle = param.firstOccurrence(sepChar, 1);
        if (!exists middle) {
            return null;
        }
        assert(exists lastIndex = param.lastIndex);
        if (middle == lastIndex) {
            return null;
        }
        try {
            value reg = regex(param[1..middle-1], global, false, false);
            return [reg, param[middle + 1..param.size-2]];
        } catch(RegexException e) {
            log.warn("Problem parsing a replacement regular expression", e);
            return null;
        }
    }
    
    value regs = replace.map(buildRegexp).coalesced;

    value httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.seconds)
        .readTimeout(30, TimeUnit.seconds)
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

    function modifyWorkspaceJson(variable String json) {
        for ([reg, repl] in regs) {
            json = reg.replace(json, repl);
        }
        return json;
    }

    shared Status migrate() {
        try {
            value endpointPath = "/workspace";
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
                        log.debug("Source Che server not accessible (error 503). Retrying ...");
                        // Wait 1 second and retry
                        Thread.sleep(1000);
                    }
                    else {
                        return Status.unexpectedErrorInSourceCheServer(response);
                    }
                } catch(SocketTimeoutException e) {
                    log.info("SocketTimeout exception when trying to access to the Source Che server. Retrying ...");
                    // Wait 1 second and retry
                    Thread.sleep(1000);
                }
            } else {
                log.error("Source Che server not accessible even after ``timeoutMinutes`` minutes at '`` sourceEndpoint ``'");
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

            if (exists running = workspaces
                .narrow<JsonObject>()
                .find((workspace) => 
                    if (exists status = workspace.getStringOrNull("status"))
                    then status != "STOPPED"
                    else false)) {
                return Status.workspacesShouldBeStopped(running.getStringOrNull("id") else "unknown");
            }
                
            value initialState = [Status.success, []];
            value [status, createdWorkspaces] = workspaces
                .narrow<JsonObject>()
                .map((workspace) => workspace.get("config"))
                .narrow<JsonObject>()
                .fold<[Status, [<String->String>*]]>(initialState)((currentState, toCreate) {

                value [status, alreadyCreated] = currentState;

                if (! status.successful()) {
                    // Skip next workspaces since migration already failed
                    return currentState;
                }

                value workspaceName = toCreate.getString("name");

                log.info(() => "Migration of workspace `` workspaceName ``");
                log.debug(() => "    Workspace configuration to create:\n`` toCreate.string ``");

                try (response = postJson(destinationEndpoint, modifyWorkspaceJson(toCreate.string))) {

                    switch(response.code())
                    case(201) {
                        if (exists responseBody = response.body()?.string_method(),
                            is JsonObject createdWorkspace = parseJSON(responseBody),
                            exists id = createdWorkspace.get("id")) {

                            log.info(() => "    => OK");
                            return [Status.success, [ id.string->workspaceName, *alreadyCreated ]];
                        } else {
                            return [Status.noIdInCreatedWorkspace(response), alreadyCreated];
                        }
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
                log.info("Created workspaces: ``
                    createdWorkspaces.map((id->name)=> name + "(id: `` id ``)") ``");
            } else {
                log.info("No workspaces created");
            }
            status.migratedWorkspaces = JsonObject { *createdWorkspaces }.string;
            return status;
        } catch(Exception e) {
            value status = Status.unexpectedException(e);
            log.error(status.description, e);
            return status;
        }
    }

    shared void rollbackCreatedWorkspace(<String->String> idAndName) {
        value id->name = idAndName;

        value endpoint = "``destinationCheServer``/workspace/``id``";
        
        try (response = send(Http().delete().url(endpoint))) {
            switch(response.code())
            case(204) {
            }
            case(403) {
                log.warn("User doesn't have right to remove workspace `` name
                        ``... This should never happen since the workspace was just created by this user");
            }
            case(409) {
                log.warn("User cannot rollback the creation of workspace `` name 
                        `` since it's already running... This should never happen since the workspace was just created by this user");
            }
            case(404) {
                log.warn("User cannot rollback the creation of workspace `` name 
                        `` since doesn't exist... This should never happen since the workspace was just created by this user");
            }
            else {
                log.warn("User cannot rollback the creation of workspace `` name ``: unexpected error");
            }
        }
    }
}
