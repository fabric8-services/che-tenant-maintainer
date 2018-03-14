import ceylon.json {
    parseJSON=parse,
    JsonObject
}
import ceylon.logging {
    debug,
    defaultPriority
}

import fr.minibilles.cli {
    option
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
import io.fabric8.kubernetes.client {
    KubernetesClientException
}


shared Migration withDefaultValues() => Migration(
    environment.multiTenantCheServer else "",
    environment.cheDestinationServer else "",
    environment.osioToken else "",
    environment.identityId else "",
    environment.requestId else "",
    environment.jobRequestId else "",
    environment.osNamespace else "",
    environment.osToken else "",
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
        String osNamespace = environment.osNamespace else "",
        String osToken = environment.osToken else "",
        Boolean debugLogs = environment.debugLogs

        ) extends NamespaceMigration(identityId, requestId, jobRequestId, osNamespace, osToken, debugLogs) {

    name = Name.name;

    shared actual Status migrate() {
        try(oc = DefaultOpenShiftClient(osConfig)) {
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
                        if (is KubernetesClientException e,
                            exists reason = e.status.reason,
                            reason == "AlreadyExists") {
                            log.debug("Lock config map already exists. Waiting for it to be released");
                        } else {
                            log.warn("Exception when trying to create the lock config map", e);
                        }
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
                value statusForWorkspaces = migrationResult.first;

                variable value status =
                    if (statusForWorkspaces.successful())
                    then Status(0, "Migration successful", statusForWorkspaces.migratedWorkspaces)
                    else Status(1, statusForWorkspaces.string, statusForWorkspaces.migratedWorkspaces);

                if (! statusForWorkspaces.migratedWorkspaces.empty) {
                    assert (exists migrator = migrationResult[1]);
                    if (is JsonObject workspacesJson = parseJSON(statusForWorkspaces.migratedWorkspaces)) {
                        value workspaces = workspacesJson.coalescedMap.map((k->v) => k->v.string ).sequence();
                        for (id->name in workspaces) {
                            log.info("Migrating workspace files for workspace `` name ``" );

                            value [code, stderr] = copyWorkspaceFiles(oc, id, name);
                            if (exists code,
                                code == 0) {
                                log.info(() => " => workspace files correctly copied for workspace `` name ``");
                            } else {
                                value detailedLog =
                                if (exists code)
                                then "Command failed with the following code: `` code `` and termination message: `` stderr else "" ``"
                                else (stderr else "");

                                String message = "Failure during migration of workspace files for workspace `` name ``: `` detailedLog ``";
                                log.error(" => `` message ``");

                                value toRollback = workspaces.skipWhile((_->n) => n != name).sequence();

                                log.info(() => " Removing the workspace definition of the following newly created workspaces: ``
                                toRollback.map(Entry.item) ``");

                                toRollback.each(migrator.rollbackCreatedWorkspace);
                                status = Status(1, message, statusForWorkspaces.migratedWorkspaces);
                                break;
                            }
                        }
                    }
                }

                if (status.code == 0) {
                    log.info(status.message);
                } else {
                    log.error(status.message);
                }
                return status;
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

    [Integer?,String?] copyWorkspaceFiles(OpenShiftClient oc, String workspaceId, String workspaceName) {

        value podName = "workspace-data-migration-" + workspaceId;
        value claimName = "claim-che-workspace";

        if (! oc.persistentVolumeClaims().withName(claimName).get() exists) {
            return [null, "PVC `` claimName `` doesn't exist !"];
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
            .withImage("registry.access.redhat.com/rhel7-atomic")
            .withImagePullPolicy("IfNotPresent")
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
                """if [ "A$(ls /old)A" == "AA" ]; then echo 'No projects to copy in this workspace'; else echo 'About to copy the following folders: ' && ls /old && cp -Rf /old/* /new 2> /dev/termination-log; fi;"""
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
            return [
                terminationStatus.exitCode.intValue(),
                terminationStatus.message of String?
            ];
        } else {
            if (exists pendingPod = oc.pods()
                .withName(podName)
                .get(),
                exists phase = pendingPod.status?.phase,
                phase == "Pending") {
                    oc.pods().withName(podName).delete();
            }
            
            return  [null, "Timeout while waiting for container creation or command execution"];
        }
    }
}

