import ceylon.logging {
    Priority
}
import ceylon.json {
    Object
}
import ceylon.time {
    systemTime
}
import java.lang {
    ThreadLocal { threadLocal = withInitial }
}

shared object logIds {
    String unknownId = "unknown";
    shared ThreadLocal<String[2]> tl = threadLocal(()=>[unknownId, unknownId]);

    shared String identity() => tl.get()[0];
    shared String request() => tl.get()[1];

    shared void setup(String? identityId, String? requestId) {
        tl.set([identityId else unknownId, requestId else unknownId]);
    }

    shared void reset() {
        tl.set([unknownId, unknownId]);
    }

    shared T resetAfter<T>(T action()) {
        try {
            return action();
        }
        finally {
            reset();
        }
    }
}

String logToJson(String?() identityId, String?() requestId)(Priority p, String m, Throwable? t) {
    variable String stacktrace = "";
    if (exists t) {
        printStackTrace(t, (st) { stacktrace += st; });
    }
    return Object({
        "time" -> systemTime.milliseconds(),
        "logger" -> "che-tenant-maintainer",
        "msg" -> m,
        "level" -> p.string,
        if (! stacktrace.empty) then "stack_trace" -> stacktrace else null,
        if (exists id = identityId(), !id.empty) then "identity_id" -> id else null,
        if (exists req = requestId(), !req.empty) then "req_id" -> req else null
    }.coalesced).string;
}