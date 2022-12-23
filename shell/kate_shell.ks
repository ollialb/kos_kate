@lazyglobal off.

include ("kate/core/kate_object").

local COMMAND_EXECUTE_TASK is "X".

// Idea:
// > X AUTP AASC mode:AUTO apogee:150 <return>
// > X 
global function KateShell {
    parameter   pRuntime.

    local this is KateObject("KateShell", "KSH").

    set this:runtime to pRuntime.
    set this:outputSize to 3. // two lines
    set this:output to list("", "",""). // of string
    set this:commandLine to list(). // of string
    set this:changeToken to 0.

    this:def("clear", KateShell_clear@).
    this:def("currentCommand", KateShell_currentCommand@).
    this:def("addSegment", KateShell_addSegment@).
    this:def("removeSegment", KateShell_removeSegment@).

    this:def("parseCommand", KateShell_parseCommand@).
    this:def("parseMessage", KateShell_parseMessage@).
    this:def("parseArguments", KateShell_parseArguments@).

    this:def("println", KateShell_println@).
    this:def("print", KateShell_print@).
    this:def("lineFeed", KateShell_lineFeed@).
     
    return this.
}

local function KateShell_clear {
    parameter this.
    this:commandLine:clear().
}

local function KateShell_currentCommand {
    parameter this.
    return this:commandLine:join(" ").
}

local function KateShell_addSegment {
    parameter this, 
              segment.
    this:commandLine:add(segment).
}

local function KateShell_removeSegment {
    parameter this.
    this:commandLine:remove(this:commandLine:length-1).
}

local function KateShell_parseCommand {
    parameter this,
              text. // string
    local segments is text:split(" ").
    if segments:length > 0 {
        local command is segments[0].
        if command = COMMAND_EXECUTE_TASK {
            this:parseMessage(segments:sublist(0, segments:length-1)).
        }
    } else {
        // TODO
    }
}

local function KateShell_parseMessage {
    parameter this,
              segments. // list of strings

    if segments:length > 1 {
        local moduleName is segments[0].
        local taskName is segments[1].
        local moduleIds is this:runtime:moduleIds.
        if moduleIds:contains(moduleName) {
            local arguments is this:parseArguments(segments:sublist(0, segments:length-2)).
        }
    } else {
        // TODO
    }
}

local function KateShell_parseArguments {
    parameter this,
              segments. // list of strings
    
    local result is lexicon().
    for segment in segments {
        local parts is segment:split(":").
        if parts:length = 2 {
            local key is parts[0].
            local value is parts[1].
            result.add(key, value).
        } else {
            this:println("ERROR: Cannot parse argument [" + segment + "]").
        }
    }
    return result.
}

local function KateShell_println {
    parameter this,
              text. 
    
    this:print(text).
    this:lineFeed().
}

local function KateShell_print {
    parameter this,
              text. 
    
    local output is this:output.
    local lastLineIndex is output:length-1.
    local lastLineContent is output[lastLineIndex].
    output:remove(lastLineIndex).
    output:add(lastLineContent + text).
    set this:changeToken to this:changeToken + 1.
}

local function KateShell_lineFeed {
    parameter this. 
    
    local output is this:output.
    output:remove(0).
    output:add("").
    set this:changeToken to this:changeToken + 1.
}

