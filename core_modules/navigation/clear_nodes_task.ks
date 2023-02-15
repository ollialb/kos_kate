@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

global function KateClearNodesTask {
    local this is KateSingleShotTask("KateClearNodesTask", "CLRND").

    this:override("uiContent", KateClearNodesTask_uiContent@).
    this:override("performOnce", KateClearNodesTask_performOnce@).

    this:def("clearNodes", KateClearNodesTask_clearNodes@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateClearNodesTask_uiContent {
    parameter   this.

    local result is list().
    result:add("Clearing all maneuver nodes.").
    return result.
}

local function KateClearNodesTask_performOnce {
    parameter   this.

    this:clearNodes().
}

local function KateClearNodesTask_clearNodes {
    parameter   this.

    local nodes is allNodes.
    for node_ in nodes {
        remove node_.
    }
}