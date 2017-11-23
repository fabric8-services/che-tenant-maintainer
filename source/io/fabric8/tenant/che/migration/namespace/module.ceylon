native("jvm")
module io.fabric8.tenant.che.migration.namespace "1.0.0" {
    shared import io.fabric8.tenant.che.migration.workspaces "1.0.0";
    shared optional import io.fabric8.tenant.che.migration.rest "1.0.0";
    import maven:io.fabric8:"openshift-client" "2.6.3";
}
