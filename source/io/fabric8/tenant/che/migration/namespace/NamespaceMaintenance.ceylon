import ceylon.file {
    File,
    parsePath,
    Nil
}
import ceylon.logging {
    debug,
    info
}

import fr.minibilles.cli {
    option
}

import io.fabric8.openshift.client {
    DefaultOpenShiftClient,
    OpenShiftClient,
    OpenShiftConfigBuilder,
    OpenShiftConfig
}
import io.fabric8.tenant.che.migration.workspaces {
    logSettings,
    log
}

import java.lang {
    JavaString=String,
    Thread {
        sleep
    }
}
import io.fabric8.kubernetes.api.model {
    ConfigMap,
    DoneableConfigMap
}
import io.fabric8.kubernetes.client {
    KubernetesClientException
}

shared abstract class NamespaceMaintenance(

        "Identity ID of the user that will have his tenant maintained"
        option("identity-id")
        shared String identityId = "",

        "ID of the last maintenance request created by the tenant services"
        option("request-id")
        shared String requestId = "",

        "ID of the JOB maintenance request currently running"
        shared String jobRequestId = "",

        "OpenShift namespace in which actions will be applied"
        option("os-namespace")
        shared String osNamespace = environment.osNamespace else "",

        "Master URL of the OpenShift cluster in which actions will be applied"
        option("os-master-url")
        shared String osMasterUrl = environment.osMasterUrl else "",
        
        "OpenShift token that will be used to apply actions in the namespace"
        option("os-token")
        shared String osToken = environment.osToken else "",

        "debug"
        option("debug-logs")
        shared Boolean debugLogs = environment.debugLogs,
        
        void configOverride(OpenShiftConfig conf) => noop()
        ) {

    value builder = OpenShiftConfigBuilder();
    if (!osNamespace.empty) {
        builder.withNamespace(osNamespace);
    }
    if (!osMasterUrl.empty) {
        builder.withMasterUrl(osMasterUrl);
    }
    if (! osToken.empty) {
        builder.withOauthToken(osToken);
    }

    shared OpenShiftConfig osConfig = builder.build();
    configOverride(osConfig);

    shared restricted(`module`) String osioCheNamespace(OpenShiftClient oc) =>
            if (!osNamespace.empty) then osNamespace else (oc.namespace else "default");

    shared formal Status proceed();

    shared Integer runAsPod() {
        logSettings.format = logToJson(()=>identityId, ()=>requestId);
        logSettings.reset(environment.debugLogs then debug else info);

        if (jobRequestId.empty) {
            log.error("JOB_REQUEST_ID doesn't exit. The maintenance operation should be started with a REQUEST_ID");
            writeTerminationStatus(1);
            return 0;
        }

        if (requestId.empty) {
            log.warn("REQUEST_ID doesn't exit. The config map is probably missing. Let's skip this maintenance operation without failing since it should be performed by another Job");
            writeTerminationStatus(0);
            return 0;
        }

        variable Integer exitCode;
        try {
            value status = proceed();
            exitCode = status.code;
            writeTerminationStatus(exitCode);
        } catch(Throwable e) {
            log.error("Unknown error during namespace maintenance operation", e);
        } finally {
            cleanMigrationResources(jobRequestId);
        }
        return 0;
    }

    void writeTerminationStatus(Integer exitCode) {
        value logFile = switch(resource = parsePath("/dev/termination-log").resource)
        case (is Nil) resource.createFile()
        case (is File) resource
        else null;
        if (exists logFile) {
            try (appender = logFile.Appender()) {
                appender.write(exitCode.string);
            }
        }
    }

    void cleanMigrationResources(String jobRequestId) {
        try(oc = DefaultOpenShiftClient(osConfig)) {
            if (exists configMap = oc.configMaps().inNamespace(osioCheNamespace(oc)).withName("migration").get(),
                exists reqId = configMap.data.get(JavaString("request-id"))?.string,
                reqId == jobRequestId) {
                oc.resource(configMap).delete();
            }
        } catch(Exception e) {
            log.warn("Exception while cleaning the Openshift resources", e);
        }
    }

    "
     Get *lock* on specified namespace, in the form of a configMap. Used to ensure multiple
     maintenance jobs cannot be run sumultaneously.

     Waits for a specified timeout before failing.
     "
    shared KubernetesResource<ConfigMap,DoneableConfigMap>|Status
    getLockResource(String namespace, Integer timeoutMinutes=10, String lockConfigMap="maintenance-lock") {
        try (oc = DefaultOpenShiftClient(osConfig)) {
            value lockResources = oc.configMaps().inNamespace(namespace).withName(lockConfigMap);
            if (lockResources.get() exists) {
                log.info("A previous maintenance Job is already running. Waiting for it to finish...");
            }
            for (retry in 0 : timeoutMinutes*60) {
                if (!lockResources.get() exists) {
                    try {
                        if (lockResources.createNew().withNewMetadata().withName(lockConfigMap).endMetadata().done() exists) {
                            break;
                        }
                    } catch (Exception e) {
                        if (is KubernetesClientException e,
                            exists reason = e.status.reason,
                            reason == "AlreadyExists") {
                            log.debug("Lock config map already exists. Waiting for it to be released");
                        } else {
                            log.warn("Exception when trying to create the lock config map", e);
                        }
                    }
                }
                sleep(1000);
            } else {
                value message = "The maintenance lock is still owned, even after a ``timeoutMinutes`` minutes in namespace '``namespace``'
                                             It might be necessary to remove the 'maintenance-lock' config map manually.";
                log.error(message);
                return Status(1, message);
            }
            return lockResources;
        }
    }
}
