import ceylon.json {
    JsonObject
}

import fr.minibilles.cli {
    option
}

import io.fabric8.kubernetes.api.model {
    PersistentVolumeClaimVolumeSourceBuilder,
    VolumeBuilder,
    VolumeMountBuilder
}
import io.fabric8.kubernetes.client {
    KubernetesClientException
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
    WorkspaceTool=Tool,
    WorkspaceStatus=Status
}
import io.jsonwebtoken {
    Jwts
}

import java.lang {
    Thread {
        sleep
    },
    JavaBoolean = Boolean
}
import java.util {
    Arrays
}

Boolean() buildTimeout(Integer timeout) {
    value end = system.milliseconds + timeout;
    return () => system.milliseconds > end;
}

shared Maintenance withDefaultValues() => Maintenance(
    environment.cheDestinationServer else "",
    environment.osioToken else "",
    false,
    false,
    environment.commandTimeout,
    environment.identityId else "",
    environment.requestId else "",
    environment.jobRequestId else "",
    environment.osNamespace else "",
    environment.osToken else "",
    environment.debugLogs
);


shared String name => Name.name;
"
 This utility will clean the user workspace-dedicated
 persistent volume from workspace directories
 that don't correspond to a workspace in the Che user account.

 It also provides an option to delete all the Che workspaces
 of the user before cleaning workspace files, in order to fully
 cleanup the user Che tenant.
 "
named(`value name`)
shared class Maintenance(
    "
        API Url of the Che server that contains workspaces to clean.
       
        For example: `https://che.openshift.io/api`
        "
    option ("che-server", 's')
    shared String cheServer,
    "
        Keycloak (OSIO) token of the user that will be migrated
        "
    option ("token", 't')
    shared String keycloakToken,
    "
        Also stop and delete the existing workspaces before cleaning workspace directories
        "
    option ("delete-all-workspaces", 'd')
    shared Boolean deleteAllWorkspaces = false,
    "
        Only simulate the cleaning but don't apply it
       
        Note that when compined with the `delete-all-workspaces`
        option, the running workspaces will still be stopped,
        but not deleted.
        "
    option ("dry-run", 'z')
    shared Boolean dryRun = false,
    "
        Timeout to wait for the cleaning command completion (in seconds)
        Default value is 10 minutes
        "
    option ("command-timeout", 'u')
    shared Integer commandTimeout = environment.commandTimeout,

    String identityId = "",
    String requestId = "",
    String jobRequestId = "",
    String osNamespace = environment.osNamespace else "",
    String osToken = environment.osToken else keycloakToken,
    Boolean debugLogs = environment.debugLogs) extends NamespaceMigration(identityId, requestId, jobRequestId, osNamespace, osToken, debugLogs, (config) {
        
        value userId =
            if (!identityId.empty)
            then identityId
            else Jwts.parser().parseClaimsJwt(keycloakToken[0 .. (keycloakToken.lastInclusion(".") else 0)]).body.subject;
        
        if (exists serviceAccountToken = cheServiceAccountTokenManager.token,
            cheServiceAccountTokenManager.useCheServiceAccountToken(userId)) {
            
            log.debug(() => "Using Che SA token for ``userId``");
            config.requestConfig.impersonateUsername = userId;
            config.oauthToken = serviceAccountToken;
        }
    }) {

    function error(String message) {
        log.error(message);
        return Status(1, message);
    }
    
    shared actual Status migrate() {
        value workspaceTool = WorkspaceTool(keycloakToken);
        value listWorkspaces = curry(workspaceTool.listWorkspaces)(cheServer);
        value getWorkspace = curry(workspaceTool.getWorkspace)(cheServer);
        value getId = workspaceTool.getId;
        value isStopped = workspaceTool.isStopped;
        value stopWorkspace = curry(workspaceTool.stopWorkspace)(cheServer);
        value deleteWorkspace = curry(workspaceTool.deleteWorkspace)(cheServer);
        
        try (oc = DefaultOpenShiftClient(osConfig)) {
            value namespace = osioCheNamespace(oc);
            
            value lockConfigMap = "maintenance-lock";
            value lockResources = oc.configMaps().inNamespace(namespace).withName(lockConfigMap);
            if (lockResources.get() exists) {
                log.info("A previous maintenance Job is already running. Waiting for it to finish...");
            }
            
            value timeoutMinutes = 10;
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
                return error("The maintenance lock is still owned, even after a ``timeoutMinutes`` minutes in namespace '``namespace``'
                                             It might be necessary to remove the 'maintenance-lock' config map manually.");
            }
            
            try {
                value workspaces = listWorkspaces();
                if (is WorkspaceStatus workspaces) {
                    return Status(1, workspaces.string);
                }
                
                {String*} workspaceIdsToKeep;
                if (deleteAllWorkspaces) {
                    for (wksp in workspaces) {
                        value id = getId(wksp);
                        if (!isStopped(wksp)) {
                            if (!stopWorkspace(wksp)) {
                                return error("The workspace ``id`` could not be stopped in namespace '``namespace``'");
                            }
                            value timeoutSeconds = 30;
                            value stopTimedOut = buildTimeout(timeoutSeconds * 1000);
                            value hasStopped =>
                                if (is JsonObject w = getWorkspace(id)) then isStopped(w) else false;
                            
                            while (!hasStopped) {
                                if (stopTimedOut()) {
                                    return error("The workspace ``id`` cannot be stopped, even after a ``timeoutSeconds`` seconds in namespace '``namespace``'");
                                }
                                sleep(1000);
                            }
                        }
                        if (dryRun) {
                            log.info(() => "should delete workspace ``id`` (dry run)");
                            continue;
                        }
                        if (!deleteWorkspace(wksp)) {
                            return error("The workspace ``id`` could not be deleted in namespace '``namespace``'");
                        }
                    }
                    
                    workspaceIdsToKeep = {};
                } else {
                    value runningWorkspaces = workspaces.filter(not(isStopped)).map(getId);
                    if (! runningWorkspaces.empty) {
                        return error("Cleaning cannot be performed since the following workspaces are running in namespace '``namespace``': ``runningWorkspaces``");
                    }
                    workspaceIdsToKeep = workspaces.map(getId);
                }
                
                Status status;
                value [code, stderr] = cleanWorkspaceFiles(oc, workspaceIdsToKeep);
                if (exists code,
                    code == 0) {
                    log.info(() => "Workspace files correctly cleaned");
                    status = Status(0, "");
                } else {
                    value detailedLog =
                        if (exists code)
                        then "Command failed with the following code: ``code`` and termination message: `` stderr else "" ``"
                        else (stderr else "");
                    
                    String message = "Failure during cleaning of workspace files: ``detailedLog``";
                    log.error(" => ``message``");
                    
                    status = Status(1, message, "");
                }
                
                if (status.code == 0) {
                    log.info(status.message);
                } else {
                    log.error(status.message);
                }
                return status;
            } catch (Exception e) {
                value message = "Unexpected exception while migrating namespace ``namespace``";
                log.error(message, e);
                return Status(1, "``message``: ``e.message``");
            } finally {
                lockResources.delete();
            }
        }
    }
    
    [Integer?, String?] cleanWorkspaceFiles(OpenShiftClient oc, {String*} workspacesIdsToKeep) {
        
        value podName = "workspace-data-cleaning-`` if (requestId.empty) then system.milliseconds / 1000 else requestId.replace("-", "") ``";
        value claimName = "claim-che-workspace";
        
        if (!oc.persistentVolumeClaims().withName(claimName).get() exists) {
            return [null, "PVC ``claimName`` doesn't exist !"];
        }
        
        value volumeName = "for-maintenance";
        
        value volume =
            VolumeBuilder()
                .withName(volumeName)
                .withPersistentVolumeClaim(
                PersistentVolumeClaimVolumeSourceBuilder()
                    .withClaimName(claimName)
                    .build())
                .build();
        
        suppressWarnings ("unusedDeclaration")
        value pod = oc
            .pods().createNew()
            .withNewMetadata()
            .withName(podName)
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
                        .withMountPath("/pvroot")
                        .withName(volumeName)
                        .build()
                ]))
            .withCommand(
                "/bin/bash",
                "-c",
                " ".join {
                    "eval 'set -e; for file in $(ls /pvroot); do",
                    "case $file in",
                    if (workspacesIdsToKeep.empty)
                    then ""
                    else "``"|".join(workspacesIdsToKeep)``) echo \"keeping $file\";;",
                    "*)",
                    if (dryRun)
                    then """echo "should remove ${file} (dry run)";;"""
                    else """echo "removing $file"; rm -Rf "/pvroot/$file";;""",
                    "esac;",
                    "done' 2> /dev/termination-log"
                })
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
        
        value commandTimedOut = buildTimeout(commandTimeout * 1000);
        variable value status = terminated();
        
        while (!status exists) {
            if (commandTimedOut()) {
                break;
            }
            sleep(1000);
            status = terminated();
        }

        if (exists commandOutput = oc.pods()
            .withName(podName)
            .getLog(JavaBoolean.true)) {
            log.info(() => "Command output:
                            ``commandOutput``");
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
            
            return [null, "Timeout while waiting for container creation or command execution"];
        }
    }
}
