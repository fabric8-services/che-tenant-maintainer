native("jvm")
module io.fabric8.tenant.che.migration.workspaces "1.0.0" {
    shared optional import maven:"javax.ws.rs:javax.ws.rs-api" "2.1";
    shared import ceylon.time "1.3.3";
    shared import ceylon.file "1.3.3";
    shared import maven:"com.squareup.okhttp3:okhttp" "3.9.1";
    shared import ceylon.json "1.3.3";
    shared import fr.minibilles.cli "0.3.0";
    shared import ceylon.logging "1.3.3";
    shared import java.base "8";
    import maven:"org.slf4j:slf4j-nop" "1.7.13";
    import ceylon.regex "1.3.3";
}
