@lazyGlobal off.

include("kate/core/kate_object").
include("kate/modules/kate_task").
include("kate/runtime/kate_process").

local STATE_INIT is "INIT".
local STATE_ACTIVE is "ACTV".
local STATE_INACTIVE is "PAUS".
local STATE_FINISHED is "FNSH".

local taskCounter is 0.

// A process wraps a particular task.
global function KateTaskProcess {
    parameter pModule, pTask, pRuntime.

    local this is KateProcess("KateTaskProcess", pModule:id + ":" + pTask:id + ":" + taskCounter).
    set taskCounter to taskCounter + 1.

    set this:local to true.
    set this:module to pModule.
    set this:task to pTask.
    set this:state to STATE_INIT.
    set this:nextExecTime to time.
    set this:lastUiContent to list().

    this:override("work", KateTaskProcess_work@).
    this:def("start", KateTaskProcess_start@).
    this:def("stop", KateTaskProcess_stop@).

    this:override("warpPoint", KateTaskProcess_warpPoint@).

    this:override("uiTitle", KateTaskProcess_uiTitle@).
    this:override("uiContent", KateTaskProcess_uiContent@).

    return this.
}

local function KateTaskProcess_work {
    parameter this.

    if this:state = STATE_FINISHED {
        return.
    }

    if this:state = STATE_INIT {
        this:start().
        set this:state to STATE_ACTIVE.
    }

    local task is this:task.
    if this:state <> STATE_FINISHED and task:finished  {
        this:stop().
        this:finish().
        set this:state to STATE_FINISHED.
    }

    if this:state = STATE_ACTIVE {
        if (this:nextExecTime - time):seconds >= -0.000001 {return.}

        local nextTime is task:safeCall0("onContinue").
        if (nextTime - time):seconds <= 0 {
            set this:nextExecTime to time.
        } else {
            set this:nextExecTime to nextTime.
        }
        set this:lastExecTime to time.
    }
}

local function KateTaskProcess_start {
    parameter this.
    local theTask is this:task.

    if this:state = STATE_FINISHED {return.}

    theTask:optionalCall0("onActivate").
    set this:nextExecTime to time.
    set this:state to STATE_ACTIVE.
    set this:module:activeTasks to this:module:activeTasks + 1.
}

local function KateTaskProcess_stop {
    parameter this.

    local theTask is this:task.
    theTask:optionalCall0("onDeactivate").
    if theTask:finished {
        set this:state to STATE_FINISHED.
    } else {
        theTask:finish().
        set this:state to STATE_FINISHED.
    }
    set this:module:activeTasks to this:module:activeTasks - 1.
}

local function KateTaskProcess_uiTitle {
    parameter this.
    local activeIndicator is choose "█ " if not this:finished else "░ ".
    return activeIndicator + this:id.
}

local function KateTaskProcess_warpPoint {
    parameter this.
    local theTask is this:task.
    local result is theTask:optionalCall0("warpPoint").
    return result.
}

local function KateTaskProcess_uiContent {
    parameter this.
    local theTask is this:task.
    if not theTask:finished set this:lastUiContent to theTask:safeCall0("uiContent").
    return this:lastUiContent.
}