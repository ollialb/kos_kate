@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

global function KateChangeInclinationTask {
    local this is KateSingleShotTask("KateChangeInclinationTask", "CH_IN").

    this:declareParameter("inclination", "0.0", "Inclination [°]: ").

    this:override("uiContent", KateChangeInclinationTask_uiContent@).
    this:override("performOnce", KateChangeInclinationTask_performOnce@).

    this:def("createNode", KateChangeInclinationTask_createNode@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateChangeInclinationTask_uiContent {
    parameter   this.
    local result is list().

    local newInclination is this:parameters["inclination"]:toScalar(0).
    result:add("Change periapsis to " + newInclination + ": " + this:message).

    return result.
}

local function KateChangeInclinationTask_performOnce {
    parameter   this.

    local newInclination is this:parameters["inclination"]:toScalar(0).
    this:createNode(newInclination).
}

local function KateChangeInclinationTask_createNode {
    parameter   this,
                newInclination.

    local etaApsis is eta:periapsis. 
    local nodeTime is time + TimeSpan(etaApsis).

    local currentOrbit is ship:orbit.
    local currentInclination is currentOrbit:inclination.
    local rotationAngle is currentInclination - newInclination.
    local apsisVelocityCurrent is velocityAt(ship, etaApsis):orbit.
    local apsisPosition is positionAt(ship, etaApsis).
    local normalBodyToShip is apsisPosition - positionAt(ship:body, etaApsis).
    local rotationAxis is angleAxis(rotationAngle, normalBodyToShip).
    local apsisVelocityDesired is rotationAxis * apsisVelocityCurrent.
    local nodeVector is (apsisVelocityDesired - apsisVelocityCurrent).

    local newNode is Node(nodeTime, nodeVector:x, nodeVector:y, nodeVector:z).
    add newNode.
    set this:message to "DeltaV " + round(nodeVector:mag, 2) + " m/s".
    
}