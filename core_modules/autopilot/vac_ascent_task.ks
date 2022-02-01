@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/library/kate_impact_predictor").

local STATE_INIT is "Initializing".
local STATE_COUNTDOWN is "Countdown".
local STATE_VERTICAL is "Vertical".
local STATE_STAGING is "Staging".
local STATE_ACCEL is "Accelerate".
local STATE_COAST_TO_AP is "Coast To Apoapsis".
local STATE_FINISHED is "Circularize".

global function KateVacuumAscentTask {
    local this is KateCyclicTask("KateVacuumAscentTask", "V_ASC", 0.01).

    this:declareParameter("apoapsis",      "150",   "apoapsis    [km]: ").
    this:declareParameter("safeElevation", "0.1",   "safe elev.  [km]: ").
    this:declareParameter("inclination",    "90",   "inclination  [°]: ").

    this:override("uiContent", KateVacuumAscentTask_uiContent@).
    
    this:def("onActivate", KateVacuumAscentTask_onActivate@).
    this:def("onDeactivate", KateVacuumAscentTask_onDeactivate@).
    this:def("onCyclic", KateVacuumAscentTask_onCyclic@).

    this:def("stageOnDemand", KateVacuumAscentTask_stageOnDemand@).
    this:def("startStage", KateVacuumAscentTask_startStage@).
    this:def("finishStage", KateVacuumAscentTask_finishStage@).
    this:def("releaseClamps", KateVacuumAscentTask_releaseClamps@).
    this:def("deployFairings", KateVacuumAscentTask_deployFairings@).

    // Helpers
    set this:ownship to KateShip().
    set this:uiContentHeight to 6. 

    // Initialize variables, which may be used by UI
    set this:state to STATE_INIT.
    set this:message to "-".
    set this:timeToLaunch to time.
    set this:currentAp to ship:altitude.
    set this:throttle to 0.
    set this:steering to up.
    set this:turnStart to 1500.
    set this:targetAp to 150000.
    set this:targetInclination to 90.
    set this:safeElevation to 2000.

    return this.
}

local function KateVacuumAscentTask_uiContent {
    parameter   this.
    
    local result is list().

    result:add("Status     : " + this:state + " [" + ship:status + "]").
    result:add("Message    : " + this:message).
    result:add("Apoapsis   : " + round(obt:apoapsis / 1000, 1) + " km over " + obt:body:name + " [" + obt:transition + "]").
    result:add("Trottle    : " + round(this:throttle * 100, 1) + " %").
    return result.
}

local function KateVacuumAscentTask_onActivate {
    parameter   this.
    
    set this:state to STATE_INIT.
    set this:message to "".
    set this:timeToLaunch to time + TimeSpan(5).
    set this:currentPa to ship:altitude.
    set this:throttle to 0.
    set this:steering to up.
    set this:afterStageState to STATE_INIT.
    set this:broke30s to false.
    set this:fairings to list().
    set this:targetInclination to this:getNumericalParameter("inclination").
    set this:targetAp to this:getNumericalParameter("apoapsis") * 1000.
    set this:safeElevation to this:getNumericalParameter("safeElevation") * 1000.
    set this:turnStart to ship:altitude + this:safeElevation.
    set this:impactPredictor to KateImpactPredictor().
    set this:hasImpact to false.
    set this:impactTime to 0.

    lock steering to this:steering.
    lock throttle to this:throttle.
    sas off.
}

local function KateVacuumAscentTask_onDeactivate {
    parameter   this.

    unlock steering.
    unlock throttle.
    sas on.
}

local function KateVacuumAscentTask_onCyclic {
    parameter   this.
    
    if this:state = STATE_INIT {
        set this:state to STATE_COUNTDOWN.
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
                set this:state to STATE_ACCEL.
            }
        }

        if this:state = STATE_ACCEL {
            this:stageOnDemand().

            //local upVector is ship:position - body:position.
            //local trajectoryPitch is vectorAngle(ship:velocity:surface, upVector).
            local steeringPitch is 0.
            if this:impactPredictor:hasImpact() {
                local impactPrediction is this:impactPredictor:averagedEstimatedImpactPosition().
                local timeToImpact is impactPrediction:time:seconds - time:seconds.
                if timeToImpact < 30 {
                    set steeringPitch to 90 - timeToImpact / 3.
                }
            }

            set this:throttle to 1.
            set this:steering to heading(this:targetInclination, steeringPitch).
            set this:message to "Accelerating at max thrust".

            if ship:orbit:apoapsis > this:targetAp {
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

local function KateVacuumAscentTask_stageOnDemand {
    parameter   this.
    
    if (maxThrust <= 0 or this:ownship:hasDepletedEnginesInCurrentStage()) and stage:ready { 
        this:startStage().
    }
}

local function KateVacuumAscentTask_startStage {
    parameter   this.
    
    set this:afterStageState to this:state.
    set this:state to STATE_STAGING.

    set this:message to "Staging in progress".
    set this:throttle to 0.
    set this:stageCompleted to time + TimeSpan(1).
    set this:steering to ship:srfprograde. 
    stage.   
}

local function KateVacuumAscentTask_finishStage {
    parameter   this.
    
    set this:state to this:afterStageState.
    set this:message to "Staging finished, resume '" + this:afterStageState + "'".
}

local function KateVacuumAscentTask_releaseClamps {
    parameter   this.

    local clamps is this:ownship:detectLaunchClamps().
    if not clamps:empty {
        set this:message to "Releasing launch clamps".
        this:ownship:releaselaunchClamps(clamps).
    }
}

local function KateVacuumAscentTask_deployFairings {
    parameter   this.
    
    local fairings is this:ownship:detectFairings().
    if not fairings:empty {
        set this:message to "Deploying fairings".
        this:ownship:deployFairings(fairings).
    }
}

