@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

global function KateCircularizeTask {
    local this is KateSingleShotTask("KateSingleShotTask", "CIRCZ").

    this:override("uiContent", KateSingleShotTask_uiContent@).
    this:override("performOnce", KateSingleShotTask_performOnce@).

    this:def("createNode", KateSingleShotTask_createNode@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateSingleShotTask_uiContent {
    parameter   this.
    local result is list().

    local etaApoapsis is eta:apoapsis.
    local etaPerapsis is eta:periapsis.

    if (etaApoapsis < etaPerapsis) {
        result:add("Circularizing at Aposapsis: " + this:message).
    } else {
        result:add("Circularizing at Periapsis: " + this:message).
    }

    return result.
}

local function KateSingleShotTask_performOnce {
    parameter   this.

    local etaApoapsis is eta:apoapsis.
    local etaPerapsis is eta:periapsis.

    if (etaApoapsis < etaPerapsis) {
        this:createNode(apoapsis, etaApoapsis).
    } else {
        this:createNode(periapsis, etaPerapsis).
    }
}

local function KateSingleShotTask_createNode {
    parameter   this,
                apsisRadius,
                etaApsis.

    local circularV is ((body:mu)/(body:radius+apsisRadius))^0.5.
    local apsisV is (2*body:mu*((1/(body:radius+apsisRadius))-(1/orbit:semimajoraxis/2)))^0.5.

    local nodeTime is time + TimeSpan(etaApsis).
    local nodeDeltaV is circularV - apsisV.
    local node is Node(nodeTime, 0, 0, nodeDeltaV).
    add node.

    set this:message to "DeltaV " + round(nodeDeltaV, 2) + " m/s".
}