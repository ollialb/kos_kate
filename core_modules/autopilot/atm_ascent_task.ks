@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/library/kate_atmosphere").
include ("kate/library/kate_dist_util").
include ("kate/library/kate_datums").

local STATE_INIT is "Initializing".
local STATE_COUNTDOWN is "Countdown".
local STATE_VERTICAL is "Vertical".
local STATE_STAGING is "Staging".
local STATE_CLIMB is "Climb / Turn".
local STATE_COAST_TO_AP is "Coast To Apoapsis".
local STATE_FINISHED is "Circularize".

local CONTROL_LAW_POLYNOMINAL is "POLY".
local CONTROL_LAW_AUTO is "AUTO".

global function KateAtmosphericAscentTask {
    local this is KateCyclicTask("KateAtmosphericAscentTask", "A_ASC", 0.01).

    this:declareParameter("apoapsis",   "150",   "apoapsis    [km]: ").
    this:declareParameter("inclination", "90",   "inclination  [°]: ").
    this:declareParameter("controlLaw", "AUTO",  "law  [POLY|AUTO]:  ").
    this:declareParameter("curvature",    "2",   "curvature    [-]: ").

    this:override("uiContent", KateAtmosphericAscentTask_uiContent@).
    
    this:def("onActivate", KateAtmosphericAscentTask_onActivate@).
    this:def("onDeactivate", KateAtmosphericAscentTask_onDeactivate@).
    this:def("onCyclic", KateAtmosphericAscentTask_onCyclic@).

    this:def("stageOnDemand", KateAtmosphericAscentTask_stageOnDemand@).
    this:def("startStage", KateAtmosphericAscentTask_startStage@).
    this:def("finishStage", KateAtmosphericAscentTask_finishStage@).
    this:def("releaseClamps", KateAtmosphericAscentTask_releaseClamps@).
    this:def("deployFairings", KateAtmosphericAscentTask_deployFairings@).

    // Helpers
    set this:ownship to KateShip().
    set this:uiContentHeight to 7. 

    // Initialize variables, which may be used by UI
    set this:state to STATE_INIT.
    set this:controlLaw to CONTROL_LAW_AUTO.
    set this:message to "-".
    set this:timeToLaunch to time.
    set this:currentAp to ship:altitude.
    set this:throttle to 0.
    set this:steering to up.
    set this:turnStart to 500.
    set this:targetAp to 150000.
    set this:maxQ to 1.
    set this:maxWallTemperature to 1500.
    set this:atmos to kate_AtmosphereAt(ship:altitude, ship:airspeed).
    set this:targetInclination to 90.
    set this:effectiveAtmosphereAltitude to ship:body:atm:height.
    set this:pitchPid to pidLoop(1, 0.1, 0.05, -95, -5).
    set this:pitchPid:setpoint to 30. // seconds to apogee

    return this.
}

local function KateAtmosphericAscentTask_uiContent {
    parameter   this.
    
    local result is list(
        "[" + this:controlLaw + "] " + this:state,
        kate_datum(" AP", UNIT_DISTANCE, obt:apoapsis, 1) + " [TGT " + this:targetAp + "]",
        kate_datum("LOA", UNIT_DISTANCE, this:effectiveAtmosphereAltitude, 1) + " THR " + round(this:throttle * 100, 1) + " %",
        kate_datum("  Q", UNIT_ATMOSPHERE, ship:q, 1) + " [LIM " + round(this:maxQ, 1) + "]",
        kate_datum("TMP", UNIT_TEMPERATURE, this:atmos:wallTemperature, 1) + " [LIM " + round(this:maxWallTemperature, 1) + "]",
        this:message
    ).
    return result.
}

local function KateAtmosphericAscentTask_onActivate {
    parameter   this.
    
    set this:state to STATE_INIT.
    set this:message to "".
    set this:timeToLaunch to time + TimeSpan(5).
    set this:currentPa to ship:altitude.
    set this:throttle to 0.
    set this:steering to up.
    set this:afterStageState to STATE_INIT.
    set this:fairings to list().
    set this:targetInclination to this:getNumericalParameter("inclination").
    set this:targetAp to this:getNumericalParameter("apoapsis") * 1000.
    set this:curvature to this:getNumericalParameter("curvature").
    set this:controlLaw to this:getParameter("controlLaw").

    lock steering to this:steering.
    lock throttle to this:throttle.
    sas off.
}

local function KateAtmosphericAscentTask_onDeactivate {
    parameter   this.

    unlock steering.
    unlock throttle.
    sas on.
}

local function KateAtmosphericAscentTask_onCyclic {
    parameter   this.

    set this:atmos to kate_AtmosphereAt(ship:altitude, ship:airspeed).
    
    if this:state = STATE_INIT {
        set this:state to STATE_COUNTDOWN.
        set this:effectiveAtmosphereAltitude to kate_nearVacuumAltitude(ship:body).
    }
    
    if this:state = STATE_STAGING {
        if time > this:stageCompleted { this:finishStage(). }
    } else {
        if this:state = STATE_COUNTDOWN {
            if time > this:timeToLaunch {
                set this:throttle to 1.
                set this:state to STATE_VERTICAL.
                stage.
                this:releaseClamps().
            } else {
                local timeLeft is this:timeToLaunch - time.
                set this:message to "Launching in " + round(timeLeft:seconds, 0) + "s".
            }
        }

        if this:state = STATE_VERTICAL {
            this:stageOnDemand().
            set this:steering to heading(this:targetInclination, 90).
            if ship:altitude > this:turnStart {
                set this:state to STATE_CLIMB.
            }
        }

        if this:state = STATE_CLIMB {
            this:stageOnDemand().

            if this:controlLaw = CONTROL_LAW_AUTO {
                if ship:altitude < this:effectiveAtmosphereAltitude {
                    set this:pitchPid:minOutput to -80.
                } else {
                    set this:pitchPid:minOutput to -95.
                }
                local steerPitch is 90 + this:pitchPid:update(time:seconds, ship:orbit:eta:apoapsis).
                set this:steering to heading(this:targetInclination, steerPitch).
                set this:message to "PtchCtr: " + round(steerPitch, 1) + "°".
            } else { // POLYNOMIAL
                local trajectoryPitch is min(90, max((max((this:effectiveAtmosphereAltitude - ship:altitude)/this:effectiveAtmosphereAltitude, 0.000001)^(this:curvature) * 90),0)).
                local steerPitch is trajectoryPitch.
                set this:steering to heading(this:targetInclination, steerPitch).
                set this:message to "PtchCtr: " + round(trajectoryPitch, 1) + "°".
            }

            if ship:orbit:apoapsis > this:targetAp {
                set this:throttle to 0.
            } else {
                set this:throttle to min(1, (this:targetAp - ship:orbit:apoapsis) / 1000).
            }

            if ship:q > this:maxQ {
                set this:throttle to min(this:throttle, 1 - ((ship:dynamicpressure - this:maxQ)/this:maxQ)).
                set this:message to ">>> Max Q Protection <<<".
            } 
            if this:atmos:wallTemperature > this:maxWallTemperature {
                set this:throttle to min(this:throttle, 1 - ((this:atmos:wallTemperature - this:maxWallTemperature)/this:maxWallTemperature)).
                set this:message to ">>> WallTemp Protection <<<".
            } 

            if ship:orbit:apoapsis >= this:targetAp - 100 and ship:altitude > ship:body:atm:height {
                set this:fairings to this:ownship:detectFairings().
                set this:state to STATE_COAST_TO_AP.
            }
        }

        if this:state = STATE_COAST_TO_AP {
            this:stageOnDemand().
            set this:throttle to 0.
            set this:steering to heading(this:targetInclination, 0).
            set this:message to "Time to Ap: " + round(eta:apoapsis, 1) + "s  " + (choose "[FAIRINGS]" if not this:fairings:empty else "").

            if ship:altitude > ship:body:atm:height and (not this:fairings:empty) {
                this:deployFairings().
                this:fairings:clear().
            }

            if ship:altitude > ship:body:atm:height {
                set this:state to STATE_FINISHED.
            }
        }
    }

    if this:state = STATE_FINISHED {
        set this:message to "Finished ascent task.".
        this:finish().
    }
}

local function KateAtmosphericAscentTask_stageOnDemand {
    parameter   this.
    
    if (maxThrust <= 0 or this:ownship:hasDepletedEnginesInCurrentStage()) and stage:ready { 
        this:startStage().
    }
}

local function KateAtmosphericAscentTask_startStage {
    parameter   this.
    
    set this:afterStageState to this:state.
    set this:state to STATE_STAGING.

    set this:message to "Staging in progress".
    set this:throttle to 0.
    set this:stageCompleted to time + TimeSpan(1).
    set this:steering to ship:srfprograde. 
    stage.   
}

local function KateAtmosphericAscentTask_finishStage {
    parameter   this.
    
    set this:state to this:afterStageState.
    set this:message to "Staging finished, resume '" + this:afterStageState + "'".
}

local function KateAtmosphericAscentTask_releaseClamps {
    parameter   this.

    local clamps is this:ownship:detectLaunchClamps().
    if not clamps:empty {
        set this:message to "Releasing launch clamps".
        this:ownship:releaselaunchClamps(clamps).
    }
}

local function KateAtmosphericAscentTask_deployFairings {
    parameter   this.
    
    local fairings is this:ownship:detectFairings().
    if not fairings:empty {
        set this:message to "Deploying fairings".
        this:ownship:deployFairings(fairings).
    }
}

