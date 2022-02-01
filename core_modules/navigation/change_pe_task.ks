@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

global function KateChangePeTask {
    local this is KateSingleShotTask("KateChangePeTask", "CH_PE").

    this:declareParameter("periapsis", "150.0", "Periapsis [km]: ").

    this:override("uiContent", KateChangePeTask_uiContent@).
    this:override("performOnce", KateChangePeTask_performOnce@).

    this:def("createNode", KateChangePeTask_createNode@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateChangePeTask_uiContent {
    parameter   this.
    local result is list().

    local newPeriapsis is this:getNumericalParameter("periapsis") * 1E3.
    result:add("Change periapsis to " + newPeriapsis + ": " + this:message).

    return result.
}

local function KateChangePeTask_performOnce {
    parameter   this.

    local newPeriapsis is this:getNumericalParameter("periapsis") * 1E3.
    this:createNode(newPeriapsis).
}

local function KateChangePeTask_createNode {
    parameter   this,
                newPeriapsis.

    local etaApsis is eta:apoapsis.            
    local ApV is (2*body:mu*((1/(body:radius+apoapsis))-(1/orbit:semimajoraxis/2)))^0.5.
	local newApV is (2*body:mu*((1/(body:radius+apoapsis))-(1/(newPeriapsis+apoapsis+body:radius*2))))^0.5.
    local nodeDeltaV is choose ApV - newApV if newPeriapsis > periapsis else newApV - ApV.

    local nodeTime is time + TimeSpan(etaApsis).
    local node is Node(nodeTime, 0, 0, nodeDeltaV).
    add node.
    set this:message to "DeltaV " + round(nodeDeltaV, 2) + " m/s".
}