"Default documentation for module `io.fabric8.tenant.che.migration.rest`."

native ("jvm")
module io.fabric8.tenant.che.migration.rest "1.0.0" {
    shared import maven:"javax.ws.rs:javax.ws.rs-api" "2.1";
    shared import maven:"io.undertow:undertow-servlet" "1.4.0.Final";
    shared import maven:"org.jboss.weld:weld-core-impl" "2.3.5.Final";
    shared import io.fabric8.tenant.che.migration.workspaces "1.0.0";
    shared import io.fabric8.tenant.che.migration.namespace "1.0.0";
}
