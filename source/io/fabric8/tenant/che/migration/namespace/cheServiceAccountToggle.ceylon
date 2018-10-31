import com.google.gson {
    JsonParser
}
import io.fabric8.tenant.che.migration.workspaces {
    log
}
import no.finn.unleash {
    DefaultUnleash,
    UnleashContext {
        contextBuilder=builder
    }
}
import no.finn.unleash.util {
    UnleashConfig {
        Builder
    }
}
import okhttp3 {
    FormBody,
    Request,
    OkHttpClient
}
import io.jsonwebtoken {
    Jwts
}
import io.fabric8.openshift.client {
    OpenShiftConfig
}

shared object cheServiceAccountTokenManager {
    
    value unleash = DefaultUnleash(object extends Builder() {
            appName("rh-che");
            unleashAPI(process.environmentVariableValue("F8_TOGGLES_API") else "http://f8toggles/api");
            instanceId(
                if (exists envVar = process.environmentVariableValue("HOSTNAME"),
                    !envVar.empty)
                then envVar
                else "che-host");
        }.build());
    
    "Id of the Che service account used by the `fabric8_oso_proxy` to secure user namespaces"
    value serviceAccountId = environment.serviceAccountId;
    
    "Secret of the Che service account used by the `fabric8_oso_proxy` to secure user namespaces"
    value serviceAccountSecret = environment.serviceAccountSecret;
    
    "URL of the `fabric8_auth` service"
    value authApiUrl = environment.authApiUrl else "http://auth/api";
    
    shared String? token;
    
    if (exists serviceAccountId,
        !serviceAccountId.empty,
        exists serviceAccountSecret,
        !serviceAccountSecret.empty) {
        log.info("Retrieving the Che service account from the 'fabric8_auth' endpoint");
    } else {
        token = null;
        return;
    }
    
    value client = OkHttpClient();
    value requestBody = FormBody.Builder()
        .add("grant_type", "client_credentials")
        .add("client_id", serviceAccountId)
        .add("client_secret", serviceAccountSecret)
        .build();
    
    value request = Request.Builder().url(authApiUrl + "/token").post(requestBody).build();
    
    try (response = client.newCall(request).execute()) {
        token = JsonParser()
            .parse(response.body()?.string_method())
            .asJsonObject
            .get("access_token")
            .asString;
        
        log.info("Che Service account token has been successfully retrieved");
    }
    
    shared Boolean useCheServiceAccountToken(String userId) =>
        unleash.isEnabled("che.serviceaccount.lockdown", contextBuilder().userId(userId).build());
    
    shared void overrideConfig(String identityId, String keycloakToken)(OpenShiftConfig config) {
        if (exists serviceAccountToken = token) {
            value userId =
                    if (!identityId.empty)
            then identityId
            else if (! keycloakToken.empty)
            then Jwts.parser().parseClaimsJwt(keycloakToken[0 .. (keycloakToken.lastInclusion(".") else 0)]).body.subject
            else null;
            
            if (exists userId,
                cheServiceAccountTokenManager.useCheServiceAccountToken(userId)) {
                
                log.debug(() => "Using Che SA token for user ``userId``");
                config.requestConfig.impersonateUsername = userId;
                config.oauthToken = serviceAccountToken;
            }
        }
    }
}
