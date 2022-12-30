@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/core_modules/autopilot/thruster_steering").
include ("kate/core_modules/autopilot/rcs_steering").

local STATE_INIT is "Initializing".
local STATE_FINISHED is "Finished".
local STATE_APPROACH is "Approaching".
local STATE_DOCKING is "Docking".


local MAX_APPROACH_THROTTLE is 0.1. // 10%
local MAX_CLOSING_SPEED is 20.0. // m/s
local MAX_APPROACH_DIST is 50.0. // m
local MAX_RCS_DIST is 200.0. // m
local MAX_RCS_SPEED is 2.0. // m/s
local MAX_DOCKING_DIST is 1.0. // m 

global function KateDockingTask {
    local this is KateCyclicTask("KateDockingTask", "DOCKG", 0.01).

    // Member variables
    set this:uiContentHeight to 8.
    set this:state to STATE_INIT.
    set this:ownPort to 0.
    set this:targetVessel to 0.
    set this:message to "".
    set this:approachSteering to 0.
    set this:dockingSteering to 0.
    set this:ownship to KateShip().

    this:declareParameter("autoPortSelect", "x", "auto port [x]: ").

    this:override("uiContent", KateDockingTask_uiContent@).
    
    this:def("onActivate", KateDockingTask_onActivate@).
    this:def("onDeactivate", KateDockingTask_onDeactivate@).
    this:def("onCyclic", KateDockingTask_onCyclic@).

    this:def("selectPort", KateDockingTask_selectPort@).

    return this.
}

local function KateDockingTask_uiContent {
    parameter   this.
    local result is list().

    local targetName is choose (this:targetVessel):name if this:targetVessel <> 0  else "N/A".
    result:add(this:state + " '" + targetName + "'").

    if this:state = STATE_APPROACH and this:approachSteering <> 0 {
        this:approachSteering:safeCall1("uiContent", result).
    }
    if this:state = STATE_DOCKING and this:dockingSteering <> 0 {
        this:dockingSteering:safeCall1("uiContent", result).
    }

    return result.
}

local function KateDockingTask_onActivate {
    parameter   this.

    set ship:control:neutralize to true.
    unlock steering.
    unlock throttle.
    rcs on.
    sas off.
}

local function KateDockingTask_onDeactivate {
    parameter   this.

    set ship:control:neutralize to true.
    unlock steering.
    unlock throttle.
    rcs off.
    sas on.
}

local function KateDockingTask_onCyclic {
    parameter   this.

    if this:ownPort <> 0 and this:ownPort:state = "PreAttached" {
        set this:state to STATE_FINISHED.
    }

    if this:state = STATE_INIT and (not hasTarget) {
        set this:state to STATE_FINISHED.
    }

    if this:state = STATE_INIT {
        // Get own docking port
        set this:ownPort to this:ownship:getMainDockingPort().
        if (this:ownPort):isType("DockingPort") {
            (this:ownPort):controlFrom().
        }

        // Identify target type
        set this:target to target.
        if (this:target):isType("Vessel") {
            set this:targetVessel to this:target.
            set this:message to "Target is vessel".
            
            local autoPortSelect is this:getBooleanParameter("autoPortSelect").
            if autoPortSelect {
                local type is choose (this:ownPort):nodeType if (this:ownPort):isType("DockingPort") else "none".
                local matchingPort is this:selectPort(this:target, type).
                if matchingPort:isType("DockingPort") {
                    set this:target to matchingPort.
                    set this:message to "Auto-selected port".
                }
            }
        } else if (this:target):isType("DockingPort") {
            set this:targetVessel to (this:target):ship.
            set this:message to "Target is docking port".
        } else {
            set this:message to "Unknown target type".
            set this:state to STATE_FINISHED.
        }
    }

    if this:state = STATE_INIT {
        // Choose initial control mode
        local targetDistance is (this:target:position - ship:position):mag.
        local targetVelocity is (this:targetVessel:velocity:orbit - ship:velocity:orbit):mag.
        if targetDistance > MAX_RCS_DIST or targetVelocity > MAX_RCS_SPEED {
            local approachOffset is MAX_APPROACH_DIST * (this:target):facing:forevector:normalized.
            set this:approachSteering to KateThrusterSteering(this:target, approachOffset, MAX_APPROACH_THROTTLE, MAX_CLOSING_SPEED, false).
            set this:state to STATE_APPROACH.
            rcs on.
            sas off.
        } else {
            local dockingOffset is MAX_DOCKING_DIST * (this:target):facing:forevector:normalized.
            set this:dockingSteering to KateRcsSteering(this:target, this:ownPort, dockingOffset, false).
            set this:state to STATE_DOCKING.
            rcs on.
            sas off.
        }
    }

    if this:state = STATE_APPROACH and this:approachSteering <> 0 {
        this:approachSteering:safeCall0("onCyclic").
        if this:approachSteering:finished {
            set this:approachSteering to 0.
            local dockingOffset is MAX_DOCKING_DIST * (this:target):facing:forevector:normalized.
            set this:dockingSteering to KateRcsSteering(this:target, this:ownPort, dockingOffset, false).
            set this:state to STATE_DOCKING.
        }
    }

    if this:state = STATE_DOCKING and this:dockingSteering <> 0 {
        this:dockingSteering:safeCall0("onCyclic").
        if this:dockingSteering:finished {
            set this:dockingSteering to 0.
            set this:state to STATE_FINISHED.
        }
    }

    if this:state = STATE_FINISHED {    
        unlock steering.
        unlock throttle.
        rcs off.
        sas on.
        set ship:control:neutralize to true.
        this:finish().
    }
}

local function KateDockingTask_selectPort {
    parameter   this,
                targetVessel,
                type.

    local allParts to targetVessel:parts.
    for part in allParts {
        if part:isType("DockingPort") and part:state = "Ready" and part:nodeType = type {
            return part.
        }
    }
    return 0.
}