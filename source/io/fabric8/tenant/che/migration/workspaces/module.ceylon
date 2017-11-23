native("jvm")
module io.fabric8.tenant.che.migration.workspaces "1.0.0" {
    shared optional import io.fabric8.tenant.che.migration.rest "1.0.0";
    shared import ceylon.time "1.3.3";
    shared import ceylon.http.client "1.3.3";
    shared import ceylon.json "1.3.3";
    import fr.minibilles.cli "0.2.1";
    shared import ceylon.logging "1.3.3";
    shared import java.base "8";
}
