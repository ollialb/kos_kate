@lazyglobal off.

include ("kate/core/kate_object").

// Idea:
// > M AUTP AASC mode:AUTO apogee:150;
// > X 
global function KateShell {
    parameter   pRuntime.

    local this is KateObject("KateShell", "KSH").

    set this:runtime to pRuntime.
    set this:outputSize to 2. // two lines
    set this:output to list(). // of string
    set this:commandLine to list(). // of string

    this:def("clear", KateShell_clear@).
    this:def("currentCommand", KateShell_currentCommand@).
    this:def("addSegment", KateShell_addSegment@).
    this:def("removeSegment", KateShell_removeSegment@).

    this:def("parseCommand", KateShell_parseCommand@).
    this:def("parseMessage", KateShell_parseMessage@).
     
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
        if command = "M" {
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
        if command = "M" {
            this:parseMessage(segments:sublist(0, segments:length-1)).
        }
    } else {
        // TODO
    }
}

