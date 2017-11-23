import ceylon.logging {
    addLogWriter,
    Priority,
    Category,
    logger,
    Logger
}
import ceylon.file {
    File
}
import ceylon.time {
    systemTime
}

shared object logSettings {
    shared variable File? file = null;
    shared variable Boolean quiet = false;
    shared variable String(Priority, String, Throwable?) format = (Priority p, String m, Throwable? t) {
        value message = "[``systemTime.instant()``] ``p.string``: ``m``";
        variable value stacktrace = "";
        if (exists t) {
            printStackTrace(t, (st) { stacktrace = "\n" + st; });
        }
        return message + stacktrace;
    };

    addLogWriter {
        void log(Priority p, Category c, String m, Throwable? t) {
            if (exists logFile = file) {
                try (appender = logFile.Appender()) {
                    appender.writeLine(format(p, m, t));
                }
            }
            if(!quiet) {
                process.writeLine(format(p, m, t));
            }
        }            
    };
    shared void reset() {
        file = null;
        quiet = false;
    }
}

shared Logger log = logger(`module`);