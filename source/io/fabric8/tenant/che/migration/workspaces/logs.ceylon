import ceylon.file {
    File
}
import ceylon.logging {
    addLogWriter,
    Priority,
    Category,
    logger,
    Logger,
    defaultPriority,
    info,
    debug
}
import ceylon.time {
    systemTime
}
import ceylon.regex { regex,
    MatchResult }

shared alias LogFormat => String(Priority, String, Throwable?);

String simpleFromat(Priority p, String m, Throwable? t) {
    variable value message = m;
    variable value stacktrace = "";
    if (exists t) {
        message += t.string;
        stacktrace += "\n";
        printStackTrace(t, (st) { stacktrace += st; });
    }
    return "[``systemTime.instant()``] ``p.string``: ``m + stacktrace``";
}

shared object logSettings {
    shared variable File? file = null;
    shared variable Boolean quiet = false;
    shared variable LogFormat format = simpleFromat;

    value regexpsToObfuscate = [
        regex("""("[^"]*token":)"[^"]+"""", true ),
        regex("""(--token=)[^,\]]+""", true )
    ];

    function obfuscate(variable String s) {
        for (r in regexpsToObfuscate) {
            s = r.replace(s, (MatchResult m) => "``m.groups[0] else ""``\"xxxxxxxxxxxxx\"");
        }
        return s;
    }

    addLogWriter {
        void log(Priority p, Category c, String m, Throwable? t) {
            String toLog =
                if (p <= debug)
                then obfuscate(m)
                else m;

            if (exists logFile = file) {
                try (appender = logFile.Appender()) {
                    appender.writeLine(format(p, toLog, t));
                }
            }
            if(!quiet) {
                process.writeLine(format(p, toLog, t));
            }
        }            
    };

    shared void reset(Priority priority = info) {
        file = null;
        quiet = false;
        defaultPriority = priority;
    }
}

shared Logger log = logger(`module`);