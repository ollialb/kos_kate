@lazyGlobal off.

include("kate/core/kate_object").

global WARP_INHIBIT is TimeStamp(-1).
global WARP_NONE is TimeStamp(0).

// A process wraps a particular task.
global function KateProcess {
    parameter pClass, pId.

    local this is KateObject(pClass, pId).

    set this:local to true.
    set this:finished to false.
    set this:lastExecTime to time.

    this:abstract("work").
    this:def("finish", KateProcess_finish@).

    this:def("warpPoint", KateProcess_warpPoint@).

    this:def("uiTitle", KateProcess_uiTitle@).
    this:def("uiContent", KateProcess_uiContent@).

    return this.
}

local function KateProcess_finish {
    parameter this.
    set this:finished to true.
}

local function KateProcess_warpPoint {
    parameter this.
    return WARP_NONE.
}

local function KateProcess_uiTitle {
    parameter this.
    local activeIndicator is choose "█ " if not this:finished else "░ ".
    return activeIndicator + this:id.
}

local function KateProcess_uiContent {
    parameter this.
    local result is list().
    result:add("N/A").
    return result.
}