import ceylon.logging {
    writeSimpleLog,
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

object logSettings {
    shared variable File? file = null;
    shared variable Boolean quiet = false;
    addLogWriter {
        void log(Priority p, Category c, String m, Throwable? t) {
            if (exists logFile = file) {
                try (appender = logFile.Appender()) {
                    appender.writeLine("[``systemTime.instant()``] ``p.string``: ``m``");
                    if (exists t) {
                        printStackTrace(t, appender.write);
                    }
                }
            }
            if(!quiet) {
                writeSimpleLog(p, c, m, t);
            }
        }            
    };
    shared void reset() {
        file = null;
        quiet = false;
    }
}

Logger log = logger(`module`);