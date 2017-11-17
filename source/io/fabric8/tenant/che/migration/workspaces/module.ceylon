native("jvm")
module io.fabric8.tenant.che.migration.workspaces
        maven:"io.fabric8.tenant:che_workspace_migration" "1.0.0" {
    shared import maven:"javax:javaee-api" "8.0";
    import ceylon.time "1.3.3";
    shared import ceylon.http.client "1.3.3";
    import ceylon.json "1.3.3";
    import fr.minibilles.cli "0.2.1";
    import ceylon.logging "1.3.3";
    shared import java.base "8";
}
