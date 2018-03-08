import ceylon.json {
    parseJSON=parse,
    JsonObject
}
import ceylon.logging {
    debug,
    defaultPriority
}

import fr.minibilles.cli {
    option,
    additionalDoc
}

import io.fabric8.kubernetes.api.model {
    PersistentVolumeClaimVolumeSourceBuilder,
    VolumeBuilder,
    VolumeMountBuilder
}
import io.fabric8.openshift.client {
    DefaultOpenShiftClient,
    OpenShiftClient
}
import io.fabric8.tenant.che.migration.namespace {
    ...
}
import io.fabric8.tenant.che.migration.workspaces {
    log,
    migrateWorkspaces=doMigration
}

import java.lang {
    Thread
}
import java.util {
    Arrays
}


shared Migration withDefaultValues() => Migration(
    environment.multiTenantCheServer else "",
    environment.cheDestinationServer else "",
    environment.osioToken else "",
    environment.identityId else "",
    environment.requestId else "",
    environment.jobRequestId else "",
    environment.debugLogs
);

"This utility will try to migrate the user's
 Che 5 workspaces into the new Che 6 server"
shared class Migration(

        "Url of the Che 5 server that contains workspaces to migrate"
        option("source", 's')
        shared String sourceCheServer,

        "Url of the Che 6 server that will receive migrated workspaces"
        option("destination", 'd')
        shared String destinationCheServer,

        "Keycloak token of the user that will be migrated"
        option("token", 't')
        shared String keycloakToken,

        String identityId = "",
        String requestId = "",
        String jobRequestId = "",
        Boolean debugLogs = false

        ) extends NamespaceMigration(identityId, requestId, jobRequestId, debugLogs) {

    name = Name.name;

    shared actual Status doMigrate() {
        try(oc = DefaultOpenShiftClient()) {
            value namespace = osioCheNamespace(oc);

            value lockResources = oc.configMaps().inNamespace(namespace).withName("migration-lock");
            if(lockResources.get() exists) {
                log.info("A previous migration Job is already running. Waiting for it to finish...");
            }

            variable value timeoutMinutes = 10;
            for(retry in 0:timeoutMinutes*60) {
                if(! lockResources.get() exists) {
                    try {
                        if (lockResources.createNew().withNewMetadata().withName("migration-lock").endMetadata().done() exists) {
                            break;
                        }
                    } catch(Exception e) {
                        log.warn("Exception when trying to create the lock config map", e);
                    }
                }
                Thread.sleep(1000);
            } else {
                value message = "The migration lock is still owned, even after a ``timeoutMinutes`` minutes in namespace '`` namespace ``'
                                 It might be necessary to remove the 'migration-lock' config map manually.";
                log.error(message);
                return Status(1, message);
            }

            try {
                value doneResources = oc.configMaps().inNamespace(namespace).withName("che6-migration-done");
                if(doneResources.get() exists) {
                    value message = "Migration skipped (already done)";
                    log.info(message);
                    return Status(0, message);
                }

                value args = {
                    "source"-> sourceCheServer,
                    "token"-> keycloakToken,
                    "destination"-> destinationCheServer,
                    "ignore-existing"-> "true",
                    "replace" -> "agents:installers",
                    if(defaultPriority == debug) "log-level" -> "DEBUG"
                }.map((name -> val)=> if (! val.empty) then "--``name``=``val``" else null)
                    .coalesced
                    .sequence();

                log.debug("Calling workspace migration utility with the following arguments:\n`` args ``");

                value migrationResult = migrateWorkspaces(args);
                value status = migrationResult.first;

                if (! status.migratedWorkspaces.empty) {
                    assert (exists migrator = migrationResult[1]);
                    if (is JsonObject workspacesJson = parseJSON(status.migratedWorkspaces)) {
                        value workspaces = workspacesJson.coalescedMap.map((k->v) => k->v.string );
                        for (id->name in workspaces) {
                            log.info("Migrating workspace files for workspace `` name ``" );
                            if (! copyWorkspaceFiles(oc, id, name)) {
                                log.warn(() => " => failure during migration of workspace files for workspace `` name ``");

                                value toRollback = workspaces.skipWhile((_->n) => n != name).sequence();

                                log.info(() => " Removing the workspace definition of the following newly created workspaces: ``
                                                toRollback.map(Entry.item) ``");

                                toRollback.each(migrator.rollbackCreatedWorkspace);
                            } else {
                                log.info(() => " => workspace files correctly copied for workspace `` name ``");
                            }
                        }
                    }
                }

                if (status.successful()) {
                    return Status(0, "Migration successful", status.migratedWorkspaces);
                } else {
                    log.error(status.string);
                    return Status(1, status.string, status.migratedWorkspaces);
                }
            } catch(Exception e){
                value message = "Unexpected exception while migrating namespace `` namespace ``";
                log.error(message, e);
                return Status(1, "`` message ``: `` e.message ``");
            } finally {
                lockResources.delete();
            }
        }
    }

    function buildTimeout(Integer timeout) {
        value end = system.milliseconds + timeout;
        return () => system.milliseconds > end;
    }

    Boolean copyWorkspaceFiles(OpenShiftClient oc, String workspaceId, String workspaceName) {

        value podName = "workspace-data-migration-" + workspaceId;
        value claimName = "claim-che-workspace";

        if (! oc.persistentVolumeClaims().withName(claimName).get() exists) {
            log.error("PVC `` claimName `` doesn't exist !");
            return false;
        }

        value volumeName = "for-migration";

        value volume =
                VolumeBuilder()
                    .withName(volumeName)
                    .withPersistentVolumeClaim(
                    PersistentVolumeClaimVolumeSourceBuilder()
                        .withClaimName(claimName)
                        .build())
                    .build();

        suppressWarnings("unusedDeclaration")
        value pod = oc
            .pods().createNew()
            .withNewMetadata()
            .withName(podName)
            .addToAnnotations("migrated-workspace", workspaceName)
            .endMetadata()
            .withNewSpec()
            .withRestartPolicy("Never")
            .withVolumes(Arrays.asList(volume))
            .addNewContainer()
            .withName(podName)
            .withImage("centos:centos7")
            .withVolumeMounts(Arrays.asList(*[
            VolumeMountBuilder()
                .withMountPath("/old")
                .withName(volumeName)
                .withSubPath(workspaceName)
                .build(),
            VolumeMountBuilder()
                .withMountPath("/new")
                .withName(volumeName)
                .withSubPath(workspaceId)
                .build()
        ]))
            .withCommand(
                "/bin/bash",
                "-c",
                "echo 'About to copy the following folders: ' && ls /old && cp -Rf /old/* /new 2> /dev/termination-log"
            )
            .endContainer()
            .endSpec()
            .done();

        function terminated() {
            if (exists pod = oc.pods()
                .withName(podName)
                .get(),
                exists containerStatuses = pod.status?.containerStatuses,
                containerStatuses.size() > 0,
                exists status = containerStatuses.get(0),
                exists terminated = status.state?.terminated) {
                return terminated;
            }
            return null;
        }

        value commandTimedOut = buildTimeout(60000);
        variable value status = terminated();

        while(! status exists) {
            if (commandTimedOut()) {
                break;
            }
            Thread.sleep(1000);
            status = terminated();
        }

        if (exists terminationStatus = status) {
            if (terminationStatus.exitCode.intValue() == 0) {
                /*
                                try {
                                    oc.pods()
                                        .withName(podName).delete();
                                    value stopTimedOut = buildTimeout(20000);

                                    while(oc.pods().withName(podName).get() exists) {
                                        if (stopTimedOut()) {
                                            log.warn("Timeout while waiting for `` podName `` POD removal");
                                            break;
                                        }
                                        Thread.sleep(1000);
                                        return false;
                                    }
                                } catch(Exception e) {
                                    log.warn("Unexpected exception while waiting for `` podName `` POD removal");
                                }
                */
                return true;
            } else {
                log.error(
                    "
                     Error during command execution: `` terminationStatus.message ``
                 ");
                return false;
            }
        } else {
            log.error(
                "
                 Timeout while waiting for command execution
                 ");
            return false;
        }
    }
}

