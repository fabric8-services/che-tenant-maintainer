import javax.ws.rs {
    applicationPath
}
import javax.ws.rs.core {
    Application
}

applicationPath("/fabric8-tenant-che-migration")
shared class MigrationApplication() extends Application() {}
