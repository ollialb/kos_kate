@lazyGlobal off.

include ("kate/modules/kate_singleshottask").
include ("kate/library/kate_ship").
include ("kate/library/kate_trajectory").

// Calculate a trajectory with given start position, velocity, ship.
global function KateTrajectoryServerTask {
    local this is KateSingleShotTask("KateTrajectoryServerTask", "TRJSV").

    this:declareParameter("requestId",   "",  "Request Id           : ").
    this:declareParameter("vessel",      "",  "Vessel name          : ").
    this:declareParameter("position",    "",  "Position      [m,m,m]: "). // Vector
    this:declareParameter("velocity",    "",  "Velocity  [m,m,m]/[s]: "). // Vector

    this:override("uiContent", KateTrajectoryServerTask_uiContent@).
    this:override("performOnce", KateTrajectoryServerTask_performOnce@).

    this:def("handleRequest", KateTrajectoryServerTask_handleRequest@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateTrajectoryServerTask_uiContent {
    parameter   this.
    local result is list().

    result:add("Processing request: " + this:message).

    return result.
}

local function KateTrajectoryServerTask_performOnce {
    parameter   this.

    local vesselName    is this:getParameter("vessel").
    local startPosition is this:getParameter("position").
    local startVelocity is this:getParameter("velocity").

    if (vesselName <> "") {
        local possibleTargets is list().
        local targetVessel is 0.
        list targets in possibleTargets.
        for candidate in possibleTargets {
            if candidate:name = vesselName {
                set targetVessel to candidate.
            }
        }
        if targetVessel <> 0 {
            set this:message to "rsvp vessel '" + targetVessel:name + "'".
            this:handleRequest(targetVessel).
        } else {
             set this:message to "unknown vessel '" + vesselName + "'".
        }
    } else {
        set this:message to "neither body nor vessel given".
    }
}

local function KateTrajectoryServerTask_handleRequest {
    parameter   this,
                pVessel,
                pStartPosition,
                pStartVelocity.

    local theShip is KateShip(pVessel).
    local shipArea is 10.
    // FIXME: Need to get this for given vessel.
    if panels {
        set shipArea to theShip:areaPrograde() / 5.
    } else {
        set shipArea to theShip:areaPrograde().
    }
    local trajectory is kate_simulateAtmosphericTrajectoryBodyCentric(this:entryPosition, this:entryVelocity, 0, 2, shipArea, pVessel, pVessel:body, 500).
    
}