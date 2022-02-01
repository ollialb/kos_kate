@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/library/kate_geodetic").
include ("kate/library/kate_atmosphere").
include ("kate/library/kate_time_util").
include ("kate/library/kate_dist_util").
include ("kate/library/kate_averaged_value").
include ("kate/library/kate_trajectory").

local STATE_INIT is "INITAL".
local STATE_ORBIT_ADJUSTMENT is "OPTIMZ".
local STATE_COAST_TO_ENTRY is "COASTE".
local STATE_AEROBRAKE is "AERBRK".
local STATE_APOAPSIS_CORRECTION is "APCORR".
local STATE_FINISHED is "FINISH".

local OPTIMIZE_CALC is "CALC".
local OPTIMIZE_BURN is "BURN".

local SEARCH_INIT is "INIT".
local SEARCH_UP is "UP".
local SEARCH_DOWN is "DOWN".
local SEARCH_FINISHED is "FINISHED".
local SEARCH_ABORTED is "ABORTED".
local RELATIVE_ERROR_MARGIN is 0.05. // 5%

local MIN_ENTRY_ALTITUDE_OFFSET is 2000.

// Performs Aerobraking
// ----------------------------------------------------------------
// General approach
//  - Define limits for maximum heat flux and stagnation point temperature
//  - Propose a candidate periapsis (Pe) and get the speed there
//  - Get atmospheric parameters for Pe
//  - Assuming full speed at Pe, calculate heat flux HF and stagnation point temperature SPT
//  - Use hill climb algorithm to find a Pe, where HF and SPT are at maximum.
//  - Create a maneuver node
//  - If trajectories is present, ...
//
global function KateAerobrakeTask {
    local this is KateCyclicTask("KateAerobrakeTask", "AERBK", 0.01).

    this:declareParameter("maxQ",           "20",  "Max Dyn Pressure        [atm]: ").
    this:declareParameter("maxWallTemp",  "1500",  "Max Wall Temperatur       [K]: ").
    this:declareParameter("safeAltitude",   "10",  "Safety Altitude          [km]: ").
    this:declareParameter("apoapsis",      "150",  "Target Apoapsis (neg off)[km]: ").
    this:declareParameter("prograde",         "",  "Enter Prograde            [x]: ").

    this:override("uiContent", KateAerobrakeTask_uiContent@).

    this:def("onActivate", KateAerobrakeTask_onActivate@).
    this:def("onDeactivate", KateAerobrakeTask_onDeactivate@).
    this:def("onCyclic", KateAerobrakeTask_onCyclic@).

    this:def("setAerobrakeConfiguration", KateAerobrakeTask_setAerobrakeConfiguration@).
    this:def("alignedThrottle", KateAerobrakeTask_alignedThrottle@).
    this:def("stageOnDemand", KateAerobrakeTask_stageOnDemand@).

    // Helpers
    set this:ownship to KateShip().
    set this:uiContentHeight to 11.

    // State
    set this:state to STATE_INIT.
    set this:message to "".
    set this:maxQ to 20000.
    set this:maxWallTemp to 1500.
    set this:prograde to false.
    set this:targetApoapsis to 150000.
    set this:safeAltitude to 10000.

    set this:hasEntry to false. 
    set this:hasExit to false. 
    set this:entryTime to 0.
    set this:entryPosition to V(0,0,0).
    set this:entryVelocity to V(0,0,0).
    set this:exitStatus to "N/A".
    set this:exitTime to 0.
    set this:exitPosition to V(0,0,0).
    set this:exitVelocity to V(0,0,0).
    set this:exitOrbit to 0.
    set this:lastOrbit to 0.
    set this:peakDynamicPressure to 0.
    set this:peakWallTemperature to 0.
    set this:lowestAltitude to 0.
    set this:simulationSteps to 0.
    set this:searchState to SEARCH_INIT.
    set this:shipArea to this:ownship:areaPrograde().
    set this:exitData1 to "".
    set this:exitData2 to "".
    set this:exitData3 to "".
    set this:exitData4 to "".
    set this:entryVec to 0.
    set this:exitVec to 0.

    set this:optimizer to OPTIMIZE_CALC.
    set this:burnStarted to TimeSpan(0).
    set this:optimizerBurnTime to 0.5.

    set this:steering to retrograde:vector.
    set this:throttle to 0.
    set this:aerobrakeConfiguration to false.

    return this.
}

local function KateAerobrakeTask_onActivate {
    parameter   this.
    
    set this:state to STATE_INIT.
    set this:searchState to SEARCH_INIT.
    set this:message to "".
    set this:maxQ to this:getNumericalParameter("maxQ") * 1E4.
    set this:maxWallTemp to this:getNumericalParameter("maxWallTemp").
    set this:prograde to this:getBooleanParameter("prograde").
    set this:targetApoapsis to this:getNumericalParameter("apoapsis") * 1E3.
    set this:safeAltitude to this:getNumericalParameter("safeAltitude") * 1E3.
    if panels {
        set this:shipArea to this:ownship:areaPrograde() / 5.
    } else {
        set this:shipArea to this:ownship:areaPrograde().
    }

    lock steering to this:steering.
    lock throttle to this:throttle.
    sas off.
}

local function KateAerobrakeTask_onDeactivate {
    parameter   this.

    set this:entryVec to 0.
    set this:exitVec to 0.
    clearVecDraws().
    unlock steering.
    unlock throttle.
    sas on.
}

local function KateAerobrakeTask_uiContent {
    parameter   this.
    local result is list().

    local throttleIndicator is choose "██" if this:throttle > 0 else "░░".
    result:add("==[" + (this:state + " : " + this:message):padright(30) + "]==========[" + throttleIndicator + " " + (round(this:throttle*100, 2) + "%"):padleft(5) + "]====").
    
    if this:hasEntry and (this:state = STATE_ORBIT_ADJUSTMENT or this:state = STATE_COAST_TO_ENTRY) {
        result:add("-- ENTRY ----------------------------------------------------------------").
        local alt_str is   ("Alt: " + kate_prettyDistance(body:altitudeOf(this:entryPosition))):padright(20).
        local speed_str is ("Spd: " + kate_prettySpeed(this:entryVelocity:mag)):padright(20).
        local time_str is  (" -T: " + kate_prettyTime(this:entryTime)):padright(20).
        result:add(alt_str + speed_str + time_str).
    } 
    if this:hasExit and this:state = STATE_ORBIT_ADJUSTMENT {
        result:add("-- AFTER AEROBRAKE ------------------------------------------------------").
        local st_str is    ("Res: " + this:exitStatus + " (" + this:simulationSteps + ")"):padright(20).
        local srch_str is  (" SD: " + this:searchState):padright(20).
        local low_str is   ("LwA: " + kate_prettyDistance(this:lowestAltitude)):padright(20).
        local steps_str is ("  N: " + round(this:simulationSteps)):padright(20).
        local alt_str is   ("Alt: " + kate_prettyDistance(body:altitudeOf(this:exitPosition))):padright(20).
        local speed_str is ("Spd: " + kate_prettySpeed(this:exitVelocity:mag)):padright(20).
        local time_str is  (" -T: " + kate_prettyTime(this:exitTime)):padright(20).
        set this:exitData1 to alt_str + speed_str + time_str.
        result:add(this:exitData1).
        if this:exitOrbit <> 0 {
            local pe_str is    (" Pe: " + kate_prettyDistance(this:exitOrbit:periapsis)):padright(20).
            local ap_str is    (" Ap: " + kate_prettyDistance(this:exitOrbit:apoapsis)):padright(20).
            local inc_str is   ("Inc: " + round(this:exitOrbit:inclination, 1)):padright(20).
            set this:exitData2 to pe_str + ap_str + inc_str.
            result:add(this:exitData2).
        }
        local qmax_str is  ("  Q: " + round(this:peakDynamicPressure  * constant:kpatoatm * 1E-4, 1) + "atm"):padright(20).
        local tmax_str is  (" Tw: " + round(this:peakWallTemperature) + "K"):padright(20).
        local dv_str is    (" dV: " + kate_prettySpeed(this:entryVelocity:mag - this:exitVelocity:mag)):padright(20).
        set this:exitData3 to qmax_str + tmax_str + dv_str.
        result:add(this:exitData3).
        set this:exitData4 to st_str + srch_str + low_str.
        result:add(this:exitData4).
    } 
    if this:state = STATE_COAST_TO_ENTRY {
         result:add("-- AFTER AEROBRAKE ------------------------------------------------------").
         result:add(this:exitData1).
         result:add(this:exitData2).
         result:add(this:exitData3).
         result:add(this:exitData4).
    }
    if this:state = STATE_AEROBRAKE {
        local atmos is kate_AtmosphereAt(ship:altitude, ship:airspeed).
        local qmax_str is  ("M Q: " + round(this:peakDynamicPressure * constant:kpatoatm / 1E4, 1) + "atm"):padright(20).
        local tmax_str is  ("MTw: " + round(this:peakWallTemperature) + "K"):padright(20).
        local dv_str is    ("MdV: " + kate_prettySpeed(this:entryVelocity:mag - this:exitVelocity:mag)):padright(20).
        local q_str is     ("  Q: " + round(ship:dynamicpressure, 1) + "atm"):padright(20).
        local t_str is     (" Tw: " + round(atmos:wallTemperature) + "K"):padright(20).
        local q2_str is    (" Q2: " + round(atmos:dynamicPressure * constant:kpatoatm / 1E4, 1) + "atm"):padright(20).
        result:add(qmax_str + tmax_str + dv_str).
        result:add(q_str + t_str + q2_str).
    }

    return result.
}

local function KateAerobrakeTask_onCyclic {
    parameter   this.

    if this:state = STATE_INIT {
        if eta:apoapsis < eta:periapsis {
            set this:message to "Aborting - must be started before periapsis".
            set this:state to STATE_FINISHED.
        } else {
            set this:state to STATE_ORBIT_ADJUSTMENT.
        }
    }

    this:stageOnDemand().

    if this:state = STATE_ORBIT_ADJUSTMENT {
        set this:message to "Adjusting orbit".
        //set this:hasEntry to false. 
        //set this:hasExit to false. 
        local currentPe is periapsis.
        local atmHeight is body:atm:height.
        local entryHeight is atmHeight - MIN_ENTRY_ALTITUDE_OFFSET.
        local clearHeight is this:safeAltitude.

        if currentPe <= clearHeight {
            set this:message to "Raising orbit".
            set this:hasEntry to false. 
            set this:hasExit to false. 
            set this:steering to prograde:vector.
            this:alignedThrottle(max(0.01, 0.1 * (clearHeight - currentPe)/clearHeight)).
            set this:searchState to SEARCH_UP.
        } else if currentPe >= entryHeight {
            set this:message to "Lowering orbit".
            set this:hasEntry to false. 
            set this:hasExit to false. 
            set this:steering to retrograde:vector.
            this:alignedThrottle(max(0.01, 0.1 * (currentPe - entryHeight)/entryHeight)).
            set this:searchState to SEARCH_DOWN.
        } else  {
            set this:message to "Optimizing trajectory".
            set this:hasEntry to true.
            set this:entryTime to eta:periapsis - kate_timeOfAltitude(atmHeight).
            set this:entryPosition to positionAt(ship, time + this:entryTime).
            set this:entryVelocity to velocityAt(ship, time + this:entryTime):orbit.

            // Burn in intervals and calculate only when not burning
            if this:searchState = SEARCH_DOWN or this:searchState = SEARCH_UP {
                if this:optimizer = OPTIMIZE_BURN and this:burnStarted:seconds = 0 {
                    this:alignedThrottle(0.01).
                    set this:burnStarted to time.
                } else  if time:seconds > this:burnStarted:seconds + 0.5   { 
                    set this:throttle to 0. 
                    set this:optimizer to OPTIMIZE_CALC.
                } 
            }
            
            if this:optimizer = OPTIMIZE_CALC {
                // kate_simulateAtmosphericTrajectoryBodyCentricVelocityVerlet
                // kate_simulateAtmosphericTrajectoryBodyCentricRK4
                local trajectory is kate_simulateAtmosphericTrajectoryBodyCentricVelocityVerlet(this:entryPosition, this:entryVelocity, 0, 5, this:shipArea).

                local bodyRelativePosition is trajectory:position - ship:body:position.
                local bodyRelativeVelocity is trajectory:velocity.
                local positionSwapYZ is V(bodyRelativePosition:X, bodyRelativePosition:Z, bodyRelativePosition:Y).
                local velocitySwapYZ is V(bodyRelativeVelocity:X, bodyRelativeVelocity:Z, bodyRelativeVelocity:Y).
                local newOrbit is createOrbit(positionSwapYZ, velocitySwapYZ, ship:body, time:seconds + this:entryTime + trajectory:time).
                set this:exitOrbit to newOrbit.

                // If the new orbit is too low, we will eventually crash, even if the trajectory simulation
                // aborted too early to actually get to the crash.
                if newOrbit:apoapsis < entryHeight and newOrbit:periapsis < entryHeight {
                    set trajectory:result to "crashed".
                }

                set this:exitStatus to trajectory:result.
                set this:simulationSteps to trajectory:steps.
                set this:hasExit to true. 
                set this:exitTime to this:entryTime + trajectory:time.
                set this:exitPosition to trajectory:position.
                set this:exitVelocity to trajectory:velocity.
                set this:peakDynamicPressure to trajectory:qMax.
                set this:peakWallTemperature to trajectory:wallTempMax.
                set this:lowestAltitude to choose 0 if trajectory:result = "crashed" else trajectory:altitudeMin.
                
                // Exit, when we are near to the critical boundaries
                local relativeQmaxError     is abs(this:peakDynamicPressure - this:maxQ)/this:maxQ.
                local relativeTmaxError     is abs(this:peakWallTemperature - this:maxWallTemp)/this:maxWallTemp.
                local relativeAltError      is abs(this:lowestAltitude - this:safeAltitude)/this:safeAltitude.
                local relativeApoapsisError is abs(this:exitOrbit:apoapsis - this:targetApoapsis)/this:targetApoapsis.
                local boundaryExceeded      is this:lowestAltitude < this:safeAltitude
                                            or this:exitOrbit:apoapsis < this:targetApoapsis
                                            or this:peakDynamicPressure > this:maxQ 
                                            or this:peakWallTemperature > this:maxWallTemp
                                            or trajectory:result = "crashed".
                local nearBoundary          is relativeQmaxError < RELATIVE_ERROR_MARGIN 
                                            or relativeTmaxError < RELATIVE_ERROR_MARGIN 
                                            or relativeAltError < RELATIVE_ERROR_MARGIN 
                                            or relativeApoapsisError < RELATIVE_ERROR_MARGIN.
                
                if this:entryVec = 0 {
                    set this:entryVec to vecDraw( { return this:entryPosition. }, { return this:entryVelocity*600. }, rgb(0.5, 1, 0.5), "ENTRY", 0.1, true, 0.1, true, true).
                    set this:exitVec  to vecDraw( { return this:exitPosition. } , { return this:exitVelocity*600. },  rgb(1, 0.5, 0.5), "EXIT",  0.1, true, 0.1, true, true).
                }

                if nearBoundary or boundaryExceeded {
                    set this:searchState to SEARCH_FINISHED.
                }

                if this:searchState = SEARCH_INIT {
                    if boundaryExceeded set this:searchState to SEARCH_UP.
                    else                set this:searchState to SEARCH_DOWN.
                } else {
                    if this:searchState = SEARCH_UP and trajectory:result = "undefined" set this:searchState to SEARCH_ABORTED.
                }

                if this:lastOrbit <> 0 {
                    local deltaApoapsisRel is abs(this:exitOrbit:apoapsis - this:lastOrbit:apoapsis)/this:lastOrbit:apoapsis.
                    local dAdt is deltaApoapsisRel / this:optimizerBurnTime.
                    if dAdt > 0.2 set this:optimizerBurnTime to this:optimizerBurnTime * 0.5.
                    //print "DADT " + dAdt + "    BT " + this:optimizerBurnTime at (10, 37).
                }
                set this:lastOrbit to this:exitOrbit.

                set this:optimizer to OPTIMIZE_BURN.
                set this:burnStarted to TimeSpan(0).
            } 

            // Fine control orbit
            if this:searchState = SEARCH_DOWN {
                set this:steering to retrograde:vector.
                this:alignedThrottle(0.01).
            } else if this:searchState = SEARCH_UP {
                set this:steering to prograde:vector.
                this:alignedThrottle(0.01).
            } else if this:searchState = SEARCH_ABORTED {
                set this:message to "Aborted search".
                set this:throttle to 0.
                set this:state to STATE_FINISHED.
            } else if this:searchState = SEARCH_FINISHED {
                set this:message to "Search complete".
                set this:throttle to 0.
                set this:state to STATE_COAST_TO_ENTRY.
                kuniverse:timewarp:warpto(time:seconds + this:entryTime - 60).
            }
        }
    }

    if this:state = STATE_COAST_TO_ENTRY {
        set this:message to "Coasting to entry".
        set this:throttle to 0.
        set this:steering to choose prograde:vector if this:prograde else retrograde:vector.
        
        local atmHeight is body:atm:height.
        set this:entryTime to eta:periapsis - kate_timeOfAltitude(atmHeight).
        set this:entryPosition to positionAt(ship, time + this:entryTime).
        set this:entryVelocity to velocityAt(ship, time + this:entryTime):orbit.

        if ship:altitude < atmHeight {
            this:setAerobrakeConfiguration(true).
            set this:state to STATE_AEROBRAKE.
        }
    }

    if this:state = STATE_AEROBRAKE {
        set this:message to "Aerobreaking".
        set this:throttle to 0.
        set this:steering to choose prograde:vector if this:prograde else retrograde:vector.
        set this:state to STATE_AEROBRAKE.

        local atmHeight is body:atm:height.
        if ship:altitude > atmHeight {
            this:setAerobrakeConfiguration(false).
            set this:state to STATE_APOAPSIS_CORRECTION.
        }
    }

    if this:state = STATE_APOAPSIS_CORRECTION {
        if (this:targetApoapsis <= 0) {
            set this:state to STATE_FINISHED.
        } else {
            set this:message to "Apoapsis correction".

            local relativeApoapsisError is (apoapsis - this:targetApoapsis)/this:targetApoapsis.
            if abs(relativeApoapsisError) < 0.01 {
                set this:throttle to 0.
                set this:state to STATE_FINISHED.
            } else if ship:orbit:apoapsis > this:targetApoapsis {
                set this:steering to retrograde:vector.
                this:alignedThrottle(relativeApoapsisError).
            } else if ship:orbit:apoapsis < this:targetApoapsis {
                set this:steering to prograde:vector.
                this:alignedThrottle(relativeApoapsisError).
            }
        }
    }

    if this:state = STATE_FINISHED {
        set this:message to "Finished aerobrake task.".
        this:finish().
    }
}

local function KateAerobrakeTask_setAerobrakeConfiguration {
    parameter this,
              state. // boolean
    
    if (not this:aerobrakeConfiguration and state) or (this:aerobrakeConfiguration and not state) {
        //local airbrakes is this:ownship:detectAirbrakes().
        //this:ownship:deployAirbrakes(airbrakes, state, state).
        if state {gear   off.}   else {gear   on.}.
        if state {panels off.}   else {panels on.}.
        if state {brakes off.}   else {brakes on.}.
        set this:aerobrakeConfiguration to state.
    }
}

// Very strict as small thrust may have huge effects
local function KateAerobrakeTask_alignedThrottle {
    parameter this,
              desiredThrottle.

    local steeringError is vAng(ship:facing:forevector, this:steering).
    if abs(steeringError) < 1 {
        set this:throttle to max(0, min(1, desiredThrottle)).
    } else {
        set this:throttle to 0.
    }
}

local function KateAerobrakeTask_stageOnDemand {
    parameter   this.
    
    if (maxThrust <= 0 or this:ownship:hasDepletedEnginesInCurrentStage()) and stage:ready { 
        stage.
    }
}