@lazyGlobal off.

include("kate/runtime/kate_process").

// Assume process died, if no heartbeat has been receibed after two minutes.
local DEAD_TIME is TimeSpan(30).
local DEAD_STATUS is " - DEAD".

global function KateRemoteProcess_fromMessage {
    parameter message,
              pId.
    local proc is KateRemoteProcess(pId).
    proc:handleUpdateMessage(message).
    return proc.
}

// Display status of a remote task
global function KateRemoteProcess {
    parameter pId.
    local this is KateProcess("KateRemoteProcess", pId).

    set this:local to false.
    set this:state to "".
    set this:remoteFinished to false.
    set this:uiTitleBuffer to "".
    set this:uiLineBuffer to list().
    set this:lastExecTime to time.

    this:override("work", KateRemoteProcess_work@).
    this:def("handleUpdateMessage", KateRemoteProcess_handleUpdateMessage@).

    this:override("uiTitle", KateTaskProcess_uiTitle@).
    this:override("uiContent", KateTaskProcess_uiContent@).

    return this.
}

local function KateRemoteProcess_work {
    parameter this.

    if this:remoteFinished {
        this:finish().
    }
    
    if (time - this:lastExecTime) > DEAD_TIME {
        set this:state to DEAD_STATUS.
        this:finish().
    }
}

local function KateRemoteProcess_handleUpdateMessage {
    parameter this,
              message.

    set this:uiTitleBuffer to message:uiTitleBuffer.
    set this:uiLineBuffer to message:uiLineBuffer.
    set this:remoteFinished to message:finished.
    set this:lastExecTime to time.
}

local function KateTaskProcess_uiTitle {
    parameter this.
    return this:uiTitleBuffer + this:state.
}

local function KateTaskProcess_uiContent {
    parameter this.
    return this:uiLineBuffer.
}