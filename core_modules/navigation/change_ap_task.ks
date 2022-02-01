@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

global function KateChangeApTask {
    local this is KateSingleShotTask("KateChangeApTask", "CH_AP").

    this:declareParameter("apoapsis", "150.0", "Apoapsis [km]: ").

    this:override("uiContent", KateChangeApTask_uiContent@).
    this:override("performOnce", KateChangeApTask_performOnce@).

    this:def("createNode", KateChangeApTask_createNode@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateChangeApTask_uiContent {
    parameter   this.
    local result is list().

    local newApoapsis is this:getNumericalParameter("apoapsis") * 1E3.
    result:add("Change apoapsis to " + newApoapsis + ": " + this:message).

    return result.
}

local function KateChangeApTask_performOnce {
    parameter   this.

    local newApoapsis is this:getNumericalParameter("apoapsis") * 1E3.
    this:createNode(newApoapsis).
}

local function KateChangeApTask_createNode {
    parameter   this,
                newApoapsis.

    local etaApsis is eta:periapsis.            
    local PeV is (2*body:mu*((1/(body:radius+apoapsis))-(1/orbit:semimajoraxis/2)))^0.5.
	local newPeV is (2*body:mu*((1/(body:radius+apoapsis))-(1/(newApoapsis+apoapsis+body:radius*2))))^0.5.
    local nodeDeltaV is choose PeV - newPeV if newApoapsis < apoapsis else newPeV - PeV.

    local nodeTime is time + TimeSpan(etaApsis).
    local node is Node(nodeTime, 0, 0, nodeDeltaV).
    add node.
    set this:message to "DeltaV " + round(nodeDeltaV, 2) + " m/s".
}