

shared object environment {
    function get(String name) =>
            if (exists var=process.environmentVariableValue(name),
                ! var.empty) then var else null;

    shared variable String? migration = get("MIGRATION");
    shared String? requestId = get("REQUEST_ID");
    shared String? identityId = get("IDENTITY_ID");
    shared String? jobRequestId = get("JOB_REQUEST_ID");
    shared String? osioToken = get("OSIO_TOKEN");
    shared String? cheNamespace = get("CHE_NAMESPACE");
    shared Boolean debugLogs = if (exists debug = get("DEBUG"))
            then debug.lowercased.trimmed == "true" else false;

    shared String? multiTenantCheServer = get("CHE_MULTITENANT_SERVER");
    shared String? cleanupSingleTenant = get("CLEANUP_SINGLE_TENANT");
    shared String? cheDestinationServer = get("CHE_DESTINATION_SERVER") else "";
}


