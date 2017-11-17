import io.fabric8.openshift.client {
    DefaultOpenShiftClient
}

String osioTokenEnvVariable="OSIO_TOKEN";
String multiTenantCheServerVariable="MULTITENANT_CHE_TOKEN";
String cheSingleTenantCheServerName="che";
String cheSingleTenantCheServerRoute="che-server";

"Run the module `io.fabric8.tenant.che.migration.namespace`."
suppressWarnings("expressionTypeNothing")
shared void run() {
    
    value keycloakToken = process.environmentVariableValue(osioTokenEnvVariable);
    value destinationCheServer = process.environmentVariableValue(multiTenantCheServerVariable);
    if(! exists keycloakToken) {
        process.exit(1);
        return;
    }
    if(! exists destinationCheServer) {
        process.exit(1);
        return;
    }
    String singleTenantCheServer;
    
    try(oc = DefaultOpenShiftClient()) {
        value cheServerDeploymentConfig = { *oc.deploymentConfigs().list().items }
            .find((dc) => dc.metadata.name == cheSingleTenantCheServerName);
        
        if (! exists cheServerDeploymentConfig) {
            // Nothing to do
            process.exit(0);
            return;
        }
        
        value cheServerRoute = { *oc.routes().list().items }
            .find((route) => route.metadata.name == cheSingleTenantCheServerRoute);
            
        if (! exists cheServerRoute) {
            // user tenant is not in a consistent state.
            // We should reset his environment in single-tenant mode
            // before retrying the migration.
            process.exit(1);
            return;
        }
        
        value spec= cheServerRoute.spec;
        singleTenantCheServer =
            "http`` if (spec.tls exists) then "s" else "" ``://``spec.host``";
    }
    
    value workspaceMigrationArguments = [
        "--token=``keycloakToken``",
        "--source=``singleTenantCheServer``",
        "--destination``destinationCheServer``",
        "--ignore-existing"
    ];
        
    print(workspaceMigrationArguments);
}
