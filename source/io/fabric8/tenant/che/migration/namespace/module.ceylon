native("jvm")
module io.fabric8.tenant.che.migration.namespace "1.0.0" {
    shared optional import maven:"javax.ws.rs:javax.ws.rs-api" "2.1";
    shared import io.fabric8.tenant.che.migration.workspaces "1.0.0";
    shared import maven:io.fabric8:"openshift-client" "3.1.12";
    shared import ceylon.interop.java "1.3.3";
    shared import fr.minibilles.cli "0.3.0";
    shared import ceylon.logging "1.3.3";
    shared import java.base "8";
    import maven:"org.slf4j:slf4j-nop" "1.7.13";
    import maven:"no.finn.unleash:unleash-client-java" "3.0.0";
    import maven:"io.jsonwebtoken:jjwt" "0.9.0";
}
