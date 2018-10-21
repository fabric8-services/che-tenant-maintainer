import ceylon.json {
    JsonArray,
    parseJSON=parse,
    JsonValue=Value,
    JsonObject
}

import java.lang {
    Thread
}
import java.net {
    SocketTimeoutException
}
import java.util.concurrent {
    TimeUnit
}

import okhttp3 {
    Request {
        Http=Builder
    },
    OkHttpClient,
    RequestBody,
    MediaType {
        contentType=parse
    },
    Response
}

shared class WorkspaceTool(shared default String keycloakToken) {
    value httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.seconds)
        .readTimeout(30, TimeUnit.seconds)
        .build();

    value authorization => ["Authorization", "Bearer ``keycloakToken``"];

    shared Response send(Http builder) => httpClient.newCall(builder
        .header(*authorization)
        .build()).execute();

    shared Response get(String endpoint) => send(Http().get()
        .url(endpoint));

    shared Response postJson(String endpoint, String content) => send(Http()
        .post(RequestBody.create(contentType("application/json"), content))
        .url(endpoint));

    shared Response delete(String endpoint) => send(Http().
        delete().url(endpoint));

    shared String workspaceEndpoint(String apiPath) => apiPath + "/workspace";

    shared Status|{JsonObject*} listWorkspaces(String apiEndpoint) {
        value sourceEndpoint = workspaceEndpoint(apiEndpoint);
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
                    log.debug("Che server (`` apiEndpoint ``) not accessible (error 503). Retrying ...");
                    // Wait 1 second and retry
                    Thread.sleep(1000);
                }
                else {
                    return Status.unexpectedErrorInSourceCheServer(response);
                }
            } catch(SocketTimeoutException e) {
                log.info("SocketTimeout exception when trying to access to the Che server (`` apiEndpoint ``). Retrying ...");
                // Wait 1 second and retry
                Thread.sleep(1000);
            }
        } else {
            log.error("Che server not accessible even after ``timeoutMinutes`` minutes at '`` sourceEndpoint ``'");
            return Status.sourceCheServerNotAccessible;
        }
        if (!exists responseContents) {
            return Status.invalidJsonInWorkspaceList("<null>");
        }

        if (responseContents.empty) {
            return Status.invalidJsonInWorkspaceList("");
        }

        //log.debug(() => "    => `` responseContents ``");

        try {
            workspaces = parseJSON(responseContents);
        } catch(Exception e) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }
        if (! is JsonArray workspaces) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }
        return workspaces.narrow<JsonObject>();
    }

    shared Status|JsonObject getWorkspace(String apiEndpoint, String id) {
        value sourceEndpoint = "``workspaceEndpoint(apiEndpoint)``/``id``";
        log.debug(() => "Retrieving the workspace description for id '`` id ``' from URL : `` sourceEndpoint `` ...");
        JsonValue workspace;

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
                    log.debug("Che server (`` apiEndpoint ``) not accessible (error 503). Retrying ...");
                    // Wait 1 second and retry
                    Thread.sleep(1000);
                }
                else {
                    return Status.unexpectedErrorInSourceCheServer(response);
                }
            } catch(SocketTimeoutException e) {
                log.info("SocketTimeout exception when trying to access to the Che server (`` apiEndpoint ``). Retrying ...");
                // Wait 1 second and retry
                Thread.sleep(1000);
            }
        } else {
            log.error("Che server not accessible even after ``timeoutMinutes`` minutes at '`` sourceEndpoint ``'");
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
            workspace = parseJSON(responseContents);
        } catch(Exception e) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }
        if (! is JsonObject workspace) {
            return Status.invalidJsonInWorkspaceList(responseContents);
        }
        return workspace;
    }

    shared Boolean deleteWorkspace(String apiEndpoint, JsonObject|<String->String?> workspace) {
        value id->name = switch(workspace) case (is JsonObject) idAndName(workspace) else workspace;

        value endpoint = "``workspaceEndpoint(apiEndpoint) ``/``id``";

        try (response = delete(endpoint)) {
            switch(response.code())
            case(204) {
                return true;
            }
            case(403) {
                log.warn("User doesn't have right to remove workspace `` name else id ``");
                return false;
            }
            case(409) {
                log.warn("User cannot rollback the creation of workspace `` name else id`` since it's already running");
                return false;
            }
            case(404) {
                log.warn("User cannot rollback the creation of workspace `` name else id `` since it doesn't exist");
                return false;
            }
            else {
                log.warn("User cannot rollback the creation of workspace `` name else id ``: unexpected error");
                return false;
            }
        }
    }

    shared [Boolean, String] stopWorkspace(String apiEndpoint, JsonObject|<String->String?> workspace) {
        value id->name = switch(workspace) case (is JsonObject) idAndName(workspace) else workspace;

        value endpoint = "``workspaceEndpoint(apiEndpoint)``/``id``/runtime";

        try (response = delete(endpoint)) {
            switch (response.code())
            case (204) {
                return [true, "success"];
            }
            case (403) {
                value message = "User doesn't have right to stop workspace ``name else id``";
                log.warn(message);
                return [false, message];
            }
            case (404) {
                value message = "User cannot stop workspace ``name else id`` since it doesn't exist";
                log.warn(message);
                return [false, message];
            }
            else {
                value message = "User cannot stop workspace ``name else id``: unexpected error";
                log.warn(message);
                return [false, message];
            }
        }
    }

    shared Boolean isStopped(JsonObject workspace) =>
            if (exists status = workspace.getStringOrNull("status"))
            then status == "STOPPED"
            else false;

    shared JsonObject getConfig(JsonObject workspace) =>
            workspace.getObject("config");

    shared String getName(JsonObject workspace) =>
            getConfig(workspace).getString("name");

    shared String getId(JsonObject workspace) =>
            workspace.getString("id");

    shared String->String idAndName(JsonObject workspace) =>
            getId(workspace) -> getName(workspace);
}