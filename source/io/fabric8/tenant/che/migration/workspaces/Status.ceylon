import ceylon.file {
    Path
}
import ceylon.http.client {
    ClientResponse=Response
}

shared class Status {
    shared static Map<Integer, String> statuses = map({
        0 -> "Successful completion",
        1 -> "Wrong command line arguments",
        2 -> "Source Che server not accessible",
        3 -> "Destination Che server not accessible",
        4 -> "Unexpected error in the source Che server",
        5 -> "Unexpected error in the destination Che server",
        6 -> "The workspace list returned by the source Che server is not valid JSON",
        7 -> "No right to create a new workspace in the destination Che server",
        8 -> "The workspace already exists in the destination Che server",
        9 -> "Log file cannot be written",
        10 -> "Unexpected exception"
    });
        
    shared Integer code;
    shared String description;
    shared String details;

    abstract new fromCode(Integer code) {
        this.code = code;
        this.description = statuses[code] else "";
    }

    abstract new simpleStatus(Integer code) extends fromCode(code) {
        this.details = "";
    }
    
    shared new success extends fromCode(0) {
        details = "\n" + "workspaces correctly migrated";
    }
    
    shared new buildHelpShown extends fromCode(0) {
        details = "\n" + buildHelp();
    }

    shared new wrongCommandLine(String* errors) extends fromCode(1) {
        details = "\n".join({"", *errors});
    }
    shared new sourceCheServerNotAccessible extends simpleStatus(2) {}
    
    shared new destinationCheServerNotAccessible extends simpleStatus(3) {}
    
    function dumpResponse(ClientResponse response)
            => "``response.status`` - `` response.contents ``";
    
    shared new unexpectedErrorInSourceCheServer(ClientResponse response) extends fromCode(4) {
        details = "\n" + dumpResponse(response);
    }
    shared new unexpectedErrorInDestinationCheServer(ClientResponse response) extends fromCode(5) {
        details = "\n" + dumpResponse(response);
    }
    shared new invalidJsonInWorkspaceList(String jsonString) extends fromCode(6) {
        details = "\n" + jsonString;
    }
    shared new noRightToCreateNewWorkspace extends simpleStatus(7) {}
    
    shared new workspaceAlreadyExists(String workspaceName) extends fromCode(8) {
        details = workspaceName;
    }
    
    shared new logFileCannotBeWritten(Path logPath) extends fromCode(9) {
        details = logPath.absolutePath.string;
    }

    shared new unexpectedException(Exception exception) extends fromCode(10) {
        details = exception.string;
    }

    string => "".join {
        "``code `` - `` description ``", 
        if(! details.empty) ": ``details``"
    };
    
    shared Boolean successful() => code == 0;
}