import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}

object env {
    function get(String name) =>
            if (exists var=process.environmentVariableValue(name),
                ! var.empty) then var else null;

    shared String? osioToken = get("OSIO_TOKEN");
    shared String? multiTenantCheServer = get("CHE_MULTITENANT_SERVER");
    shared String? requestId = get("REQUEST_ID");
    shared String? identityId = get("IDENTITY_ID");
    shared String? cheNamespace = get("CHE_NAMESPACE");
    shared String? debugLogs = get("DEBUG");
    shared String? cleanupSingleTenant = get("CLEANUP_SINGLE_TENANT");
    shared String? jobRequestId = get("JOB_REQUEST_ID");
}
String cheSingleTenantCheServerName="che";
String cheSingleTenantCheServerRoute="che";

String osioCheNamespace(DefaultOpenShiftClient oc) =>
        env.cheNamespace else oc.namespace;