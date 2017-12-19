native("jvm")
module io.fabric8.tenant.che.migration.namespace "1.0.0" {
    shared optional import maven:"javax.ws.rs:javax.ws.rs-api" "2.1";
    shared import io.fabric8.tenant.che.migration.workspaces "1.0.0";
    import maven:io.fabric8:"openshift-client" "2.6.3";
    import ceylon.interop.java "1.3.3";
    import maven:"org.slf4j:slf4j-nop" "1.7.13";
}
