@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_time_util").
include ("kate/library/kate_ship").
include ("kate/library/kate_steering").
include ("kate/library/kate_datums").

local STATE_INIT is "INIT".
local STATE_WAIT_BURN_START is "WAIT".
local STATE_BURN is "BURN".
local STATE_FINISHED is "DONE".

global function KateExecNodeTask {
    local this is KateCyclicTask("KateExecNodeTask", "EXNOD", 0.01).

    this:declareParameter("staging", "AUTO", "string {OFF|AUTO} - determines if staging shall be performed.").

    this:override("warpPoint", KateExecNodeTask_warpPoint@). // returns: timestamp. 0 means none, negative means inhibit
    this:override("uiContent", KateExecNodeTask_uiContent@).
    
    this:def("onActivate", KateExecNodeTask_onActivate@).
    this:def("onDeactivate", KateExecNodeTask_onDeactivate@).
    this:def("onCyclic", KateExecNodeTask_onCyclic@).

    this:def("stageOnDemand", KateExecNodeTask_stageOnDemand@).

    // Initialize variables, which may be used by UI
    set this:burnTime to -1.
    set this:nodeTime to TimeStamp().
    set this:burnStart to TimeStamp().
    set this:warpTime to TimeStamp(0).
    set this:state to STATE_INIT.
    set this:burnPhase to "-".
    set this:message to "-".
    set this:uiContentHeight to 1.
    set this:stagingMode to "AUTO".

    // Helpers
    set this:ownship to KateShip().
    set this:steering to KateSteering().

    return this.
}

local function KateExecNodeTask_warpPoint {
    parameter   this.
    if vectorAngle(ship:facing:forevector, this:burnVector) < 1 and this:state = STATE_WAIT_BURN_START {
        return this:burnStart.
    } else {
        return TimeStamp(0).
    }
}

local function KateExecNodeTask_uiContent {
    parameter   this.
    local result is list().

    local node_ is nextNode.
    local burnStartIn is this:burnStart - time.

    if this:state = STATE_INIT or this:state = STATE_WAIT_BURN_START {
        result:add("WAIT " + ("T- " + kate_prettyTime(burnStartIn) + " "):padright(12)            + kate_datum("DV ", UNIT_SPEED, node_:deltav:mag, 1)).
    } else if this:state = STATE_BURN {
        result:add("BURN " + ("T- " + kate_prettyTime(this:remainingActualBurnTime)):padright(12) + kate_datum("DV ", UNIT_SPEED, this:remainingDeltaV, 1)).
    } else if this:state = STATE_FINISHED {
        // Nothing
    }
    return result.
}

local function KateExecNodeTask_onActivate {
    parameter   this.

    local node_ is nextNode.
    local nodeTime is TimeStamp(node_:time).
    local burnTime is (node_:deltav:mag*mass)/availablethrust * 1.1.
    local burnStart is nodeTime - TimeSpan(burnTime*0.5).
    local burnVector is node_:deltav.

    set this:node to node_.
    set this:nodeTime to nodeTime.
    set this:burnTime to burnTime.
    set this:burnStart to burnStart.
    set this:burnVector to burnVector.
    set this:burnPhase to "MAX".
    set this:warpTime to burnStart - TimeSpan(5).
    set this:remainingMinBurnTime to burnTime.
    set this:remainingActualBurnTime to burnTime.
    set this:remainingDeltaV to node_:deltav:mag.
    set this:initialDeltaVec to node_:deltav.
    set this:finalDeltaV to 0.
    set this:throttle to 0.
    set this:state to STATE_INIT.
    set this:message to "Initialized".
    set this:stagingMode to this:getParameter("staging").
    set this:outOfFuelTime to 0.
}

local function KateExecNodeTask_onDeactivate {
    parameter   this.

    set this:warpTime to TimeStamp(0).

    unlock throttle.
    this:steering:disable().
}

local function KateExecNodeTask_onCyclic {
    parameter   this.

    local node_ is this:node.

    if this:state = STATE_INIT and (not hasNode) {
        set this:message to "Node lost".
        set this:state to STATE_FINISHED. 
    }

    if this:state = STATE_INIT {
        this:steering:enable(STEERING_SAS_MODE, "MANEUVER", this:burnVector).
        lock throttle to this:throttle.
        set this:state to STATE_WAIT_BURN_START.
    }

    if this:state = STATE_WAIT_BURN_START {
        if time > this:burnStart {
            set this:state to STATE_BURN.
        }
    }

    if this:state = STATE_BURN {
        set this:remainingMinBurnTime to choose (node_:deltav:mag*mass)/availableThrust if availableThrust > 0 else 999999.
        set this:remainingActualBurnTime to choose this:remainingMinBurnTime/this:throttle if this:throttle > 0 else 999999.
        set this:remainingDeltaV to node_:deltav:mag.
        local angle is vectorDotProduct(this:initialDeltaVec, node_:deltav).

        if this:remainingDeltaV / this:initialDeltaVec:mag <= 0.00001 or angle < 0 {
            set this:message to "Vector error in target bounds".
            set this:burnPhase to "OFF".
        }
        if this:remainingMinBurnTime <= 2 and this:burnPhase = "MAX" {
            set this:finalDeltaV to this:remainingDeltaV.
            set this:message to "Precision DeltaV Burn: " + round(this:finalDeltaV, 2) + " m/s".
            set this:burnPhase to "PRV".
            set this:throttle to max(this:remainingMinBurnTime / 2, 0.01).
        }

        if this:burnPhase = "OFF" {
            set this:throttle to 0.
            set this:state to STATE_FINISHED.
        } else if this:burnPhase = "MAX" {
            set this:throttle to 1.
        } else if this:burnPhase = "PRV" {
            set this:throttle to max(min(this:throttle, this:remainingDeltaV/this:finalDeltaV), 0.01).
        }

        if availablethrust = 0 and not stage:ready {
            if this:outOfFuelTime = 0 {
                set this:outOfFuelTime to time.
            } else if time - this:outOfFuelTime > TimeSpan(2) {
                set this:state to STATE_FINISHED.
                set this:message to "Out of fuel and stages".
                this:finish().
            }
        } else {
            set this:outOfFuelTime to 0.
        }

        this:stageOnDemand().
    }

    if this:state = STATE_FINISHED {
        remove this:node.
        set this:message to "Node finished.".
        this:finish().
    }
}

local function KateExecNodeTask_stageOnDemand {
    parameter   this.
    
    if (maxThrust <= 0 or this:ownship:hasDepletedEnginesInCurrentStage()) and stage:ready { 
        stage.
    }
}
