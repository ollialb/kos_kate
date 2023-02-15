@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_time_util").
include ("kate/library/kate_ship").
include ("kate/library/kate_dist_util").
include ("kate/library/kate_averaged_value").
include ("kate/library/kate_impact_predictor").
include ("kate/library/kate_atmosphere").
include ("kate/library/kate_terrain").
include ("kate/library/kate_datums").

local DRAW_VECTORS to true.

local STATE_INIT is "INIT".
local STATE_COAST_TO_DEORBIT is "WAIT DOBT".
local STATE_ORBIT_ADJUSTMENT is "ADJS ORBT".
local STATE_DEORBIT is "DEOBT".
local STATE_LAND is "LAND".
local STATE_FINISHED is "DONE".

local SUBSTATE_NONE is "----".
local SUBSTATE_ORBIT_ADJUSTMENT_INC is "INCL".
local SUBSTATE_ORBIT_ADJUSTMENT_DEORBIT_ALTITUDE is "ALTD".
local SUBSTATE_LAND_ALIGN is "ALGN".
local SUBSTATE_LAND_SUICIDE_BURN is "SBRN".
local SUBSTATE_LAND_FINAL is "FINL".

local MAX_WALL_TEMP is 1500.
local INFINITE_TIME is 1000000000.

// Performs a point landing
global function KatePointLandTask {
    local this is KateCyclicTask("KatePointLandTask", "PTLND", 0.01).

    this:declareParameter("latitude", "0", "latitude [°]: ").
    this:declareParameter("longitude", "0", "longitude [°]:  ").
    this:declareParameter("maxSlope", "2.5", "max slope [°]:  ").
    this:declareParameter("lowDeorbit", "", "low deorbit [x]:  ").

    this:override("uiContent", KatePointLandTask_uiContent@).
    
    this:def("onActivate", KatePointLandTask_onActivate@).
    this:def("onDeactivate", KatePointLandTask_onDeactivate@).
    this:def("onCyclic", KatePointLandTask_onCyclic@).

    this:def("stageOnDemand", KatePointLandTask_stageOnDemand@).
    this:def("greatCircleDistance", KatePointLandTask_greatCircleDistance@).
    this:def("greatCircleAzimuth", KatePointLandTask_greatCircleAzimuth@).
    this:def("geoCoordinatesAtTime", KatePointLandTask_geoCoordinatesAtTime@).
    this:def("surfaceHeading", KatePointLandTask_surfaceHeading@).
    this:def("alignedAcceleration", KatePointLandTask_alignedAcceleration@).
    this:def("alignedThrottle", KatePointLandTask_alignedThrottle@).
    this:def("timeOfAltitude", KatePointLandTask_timeOfAltitude@).
    this:def("timeBetweenAltitudes", KatePointLandTask_timeBetweenAltitudes@).
    this:def("atmDensityAt", KatePointLandTask_atmDensityAt@).
    this:def("setLandingConfiguration", KatePointLandTask_setLandingConfiguration@).
    this:def("finalSteering", KatePointLandTask_finalSteering@).

    // Initialize variables, which may be used by UI
    set this:uiContentHeight to 7.

    set this:state to STATE_INIT.
    set this:message to "-".
    set this:steering to retrograde.
    set this:throttle to 0.

    set this:seaLevelGravity to (constant:G * body:mass) / body:radius^2.
    set this:gravity to this:seaLevelGravity / ((body:radius+altitude) / body:radius)^2.
    set this:hasAtmosphere to ship:body:atm:exists.

    set this:targetPosition to latlng(0, 0).
    set this:targetElevation to 0.
    set this:targetRotationalVelocity to 0.
    set this:shipPosition to ship:geoposition.
    set this:shipClearAltitude to altitude.
    set this:surfaceDistance to 0.
    set this:surfaceSpeed to 0.
    set this:heatFlux to 0.
    set this:dragForce to 0.
    set this:wallTemperature to 0.
    set this:availableEngineAcceleration to 0.
    set this:landingConfiguration to false.
    set this:maxSlope to 5.

    set this:lowDeorbit to false.
    set this:deorbitDistance to 0.
    set this:deorbitAltitude to 100000.
    set this:deorbitAltitudeError to 0.
    
    set this:impactPredictor to KateImpactPredictor().
    set this:impactPositionAveraged to KateAveragedValue("impactPosition", 10, V(0,0,0)).
    set this:impactTimeAveraged to KateAveragedValue("impactTime", 10, 0).
    set this:impactPosition to V(0,0,0).
    set this:impactTime to TimeStamp(0).
    set this:courseError to 0.
    set this:surfaceVelocityHeading to 0.
    set this:targetAzimuth to 0.

    set this:suicideBurnTime to 0.
    set this:suicideBurnAltitude to 0.
    set this:landPid to pidLoop(0.025, 0.0001, 0.001, -1, 1, 0).
    set this:lateralPid to pidLoop(0.025, 0.0001, 0.01).
    set this:finalPid to pidLoop(10, 0.001, 0.1).
    set this:landCorrection to 0.
    
    set this:steeringVector to 0.
    set this:targetVector to 0. 
    set this:impactVector to 0.
    set this:subState to SUBSTATE_NONE.

    set this:targetPositionSlope to 0.

    // Helpers
    set this:ownship to KateShip().

    return this.
}

local function KatePointLandTask_uiContent {
    parameter   this.
    local result is list().

    local COL is 14.

    result:add(this:state + " [" + this:subState + "]" + (choose " [ATM]" if this:hasAtmosphere else "") + (choose " [LOW]" if this:lowDeorbit else "") + " " + this:message:padright(30)).
    result:add(kate_datum("LAT", UNIT_DEGREE, this:targetPosition:lat, 4, COL)   + kate_datum("LNG", UNIT_DEGREE, this:targetPosition:lng, 4, COL)         + kate_datum("ELV", UNIT_DISTANCE, this:targetElevation, 2, COL)).
    result:add(kate_datum("DTT", UNIT_DISTANCE, this:surfaceDistance, 1, COL)    + kate_datum("TPT", UNIT_DISTANCE, this:targetPosition:distance, 1, COL)  + kate_datum("VSP", UNIT_SPEED, ship:verticalspeed, 1, COL)).
    result:add(kate_datum("HSP", UNIT_SPEED, this:surfaceSpeed, 1, COL)          + kate_datum("HDG", UNIT_DEGREE, this:targetPosition:heading, 1, COL)     + kate_datum("TWR", UNIT_NONE, this:availableEngineAcceleration / this:gravity, 2, COL)).
    result:add(kate_datum("SLO", UNIT_DEGREE, this:targetPositionSlope, 1, COL)  + kate_datum("DRG", UNIT_FORCE, this:dragForce, 1, COL)                   + kate_datum("TMP", UNIT_TEMPERATURE, this:wallTemperature, 0, COL)).
    if this:state = STATE_ORBIT_ADJUSTMENT or this:state = STATE_COAST_TO_DEORBIT {
        result:add(kate_datum("ROT", UNIT_SPEED, this:targetRotationalVelocity, 1, COL)    + kate_datum("AZI", UNIT_DEGREE, this:targetAzimuth, 2, COL)       + kate_datum("THR", UNIT_PERCENT, this:throttle*100, 1, COL)).
        result:add(kate_datum("CER", UNIT_DEGREE, this:courseError, 2, COL)                + kate_datum("DOD", UNIT_DISTANCE, this:deorbitDistance, 1, COL)   + kate_datum("DOA", UNIT_DISTANCE, this:deorbitAltitude, 1, COL)).
    }
    if this:state = STATE_DEORBIT {
        result:add(kate_datum("CER", UNIT_DEGREE, this:courseError, 2, COL) + kate_datum("THR", UNIT_PERCENT, this:throttle*100, 1, COL) + "                       ").
        result:add("":padright(60)).
    }
    if this:state = STATE_LAND {
        local impactToTargetDistance is (this:impactPosition - this:targetPosition:position):mag.
        result:add(("BRN " + kate_prettyTime(this:suicideBurnTime)):padright(COL)                               + kate_datum("ALT", UNIT_DISTANCE, this:suicideBurnAltitude, 2, COL) + kate_datum("THR", UNIT_PERCENT, this:throttle*100, 1, COL)).
        result:add(("ETA " + kate_prettyTime(TimeSpan(time:seconds - this:impactTime:seconds))):padright(COL)   + kate_datum("DST" , UNIT_DISTANCE, impactToTargetDistance, 2, COL)  + kate_datum("RAD", UNIT_DISTANCE, this:shipClearAltitude, 1, COL)).
    }
    return result.
}

local function KatePointLandTask_onActivate {
    parameter   this.
}

local function KatePointLandTask_onDeactivate {
    parameter   this.

    if DRAW_VECTORS {
        clearVecDraws().
        set this:steeringVector to 0.
        set this:targetVector to 0.
        set this:impactVector to 0.
        set this:downVector to 0.
    }
    ship:control:neutralize().
    set this:throttle to 0.
    unlock steering.
    unlock throttle.
    rcs off.
    sas on.
}

local function KatePointLandTask_onCyclic {
    parameter   this.

    if this:state = STATE_INIT {
        set this:message to "Initializing".
        local strTgtLat is this:getParameter("latitude").
        local strTgtLng is this:getParameter("longitude").
        local strLowDeorbit is this:getParameter("lowDeorbit").
        set this:maxSlope to this:getParameter("maxSlope"):toScalar.
        set this:targetPosition to latlng(strTgtLat:toNumber, strTgtLng:toNumber).
        set this:targetElevation to max(0, this:targetPosition:terrainHeight).
        set this:targetPositionSlope to kate_terrainSlope(body, this:targetPosition:position).
        set this:lowDeorbit to strLowDeorbit = "x".
        set this:hasAtmosphere to ship:body:atm:exists.
        if this:hasAtmosphere {
            set this:deorbitAltitude to ship:body:atm:height.
        } else {
            set this:deorbitAltitude to this:targetElevation + 10000. // Hopefully this is enough :-)
        }
        set this:steering to retrograde:vector.
        set this:throttle to 0.
        lock steering to this:steering.
        lock throttle to this:throttle.
        rcs on.
        sas off.

        local surfaceDistance to this:greatCircleDistance(this:shipPosition, this:targetPosition).
        if surfaceDistance < 20000 and ship:groundspeed < 100 and ship:altitude > surfaceDistance * 2 {
            set this:state to STATE_LAND.
            set this:subState to SUBSTATE_LAND_ALIGN.
        } else {    
            set this:state to STATE_ORBIT_ADJUSTMENT. 
        }

        if DRAW_VECTORS {
            set this:steeringVector to vecDraw(
                { return ship:position. },
                { return this:steering. },
                rgb(0, 1, 0),
                "STR",
                10,
                true,
                0.1,
                true,
                true
            ).
            set this:targetVector to vecDraw(
                { return ship:position. },
                { return this:targetPosition:position - ship:position. },
                rgb(0.5, 0.5, 1),
                "TGT",
                1,
                true,
                0.1,
                true,
                true
            ).
            set this:targetVector to vecDraw(
                { return ship:position. },
                { return this:impactPosition. },
                rgb(1, 0.5, 0.5),
                "IMP",
                1,
                true,
                0.1,
                true,
                true
            ).
            set this:downVector to vecDraw(
                { return ship:position. },
                { return heading(0, -90, 0):vector * (ship:altitude - this:targetElevation). },
                rgb(1, 1, 0),
                "DN",
                1,
                true,
                0.1,
                true,
                true
            ).
        }
    } else {
        this:stageOnDemand().
    }

    if this:targetPositionSlope > this:maxSlope {
        local downhillVector is kate_downhillVector(body, this:targetPosition:position).
        local newTargetPosition is body:geopositionof(this:targetPosition:position + downhillVector).

        set this:targetPosition to newTargetPosition.
        set this:targetElevation to max(0, this:targetPosition:terrainHeight).
        set this:targetPositionSlope to kate_terrainSlope(body, this:targetPosition:position). 
        set this:message to "Adjusting target pos for slope".
    }

    if this:state <> STATE_FINISHED {
        set this:gravity to this:seaLevelGravity / ((body:radius+altitude) / body:radius)^2.
        set this:shipPosition to ship:geoposition.
        set this:groundElevation to ship:geoposition:terrainHeight.
        //set this:shipClearAltitude to max(0.1, min(altitude , altitude - this:groundElevation - SAFE_SHIP_HEIGHT)).
        set this:shipClearAltitude to this:ownship:radarAltitude().
        set this:surfaceDistance to this:greatCircleDistance(this:shipPosition, this:targetPosition).
        set this:targetAzimuth to this:greatCircleAzimuth(this:shipPosition, this:targetPosition).
        set this:surfaceVelocityHeading to this:surfaceHeading().
        set this:courseError to this:targetAzimuth - this:surfaceVelocityHeading.
        set this:surfaceSpeed to groundSpeed.
        set this:availableEngineAcceleration to ship:availablethrust / ship:mass.
        set this:targetRotationalVelocity to ship:body:radius * ship:body:angularvel:mag * cos(this:targetPosition:lat).
        set this:targetPositionSlope to kate_terrainSlope(body, this:targetPosition:position).

        // Calculate atmosphere
        if this:hasAtmosphere {
            local atmos is kate_atmosphereAt(ship:altitude, ship:airspeed).
            set this:heatFlux to atmos:heatFlux.
            set this:wallTemperature to atmos:wallTemperature.
            set this:dragForce to 0.5 * ship:dynamicpressure * constant:atmtokpa * 1E3 * ship:airspeed * 0.2 * 10. // Cd=0.2, Area=10m^2
        }
    }

    // Orbit adjustment phase
    //
    // We need to make sure that the "estimated landing point" is sufficiently close to where the target is going to be, when we actually
    // make it there.
    //
    //   Solution Approach: 
    //     1. Calculate rotational speed of target
    //     2. Calculate approx. time of landing and descent 
    //        - time spent in nearly circular orbit
    //        - time needed for descent
    //     3. Calculate corrected targetPosition (lat, lng) after time
    //     4. Calculate intercept ve
    //
    // Also, when should we tilt the orbit?
    if this:state = STATE_ORBIT_ADJUSTMENT {
        // Assuming no staging needed, and same orbit direction and not much correction needed,
        // decelerate to rotational velocity from current velocity takes including some extra fudge factor:
        local deceleration is max(0.0001, this:availableEngineAcceleration).
        local decelerationBurnTime is TimeSpan((this:surfaceSpeed - this:targetRotationalVelocity) / deceleration).
        local remainingOrbitTime is TimeSpan(this:surfaceDistance / ((this:surfaceSpeed + this:targetRotationalVelocity))).
        local freeFallTime is TimeSpan(sqrt(2 * (ship:altitude - this:targetElevation) / this:seaLevelGravity)).
        local freeFallVelocity is this:seaLevelGravity * freeFallTime:seconds.
        local suicideBurnTime is TimeSpan(freeFallVelocity / deceleration).
        local totalTimeToTarget is remainingOrbitTime - decelerationBurnTime + freeFallTime + suicideBurnTime.
        local timeAtTarget is time + totalTimeToTarget.

        // Corrected position of target after given time
        local targetPositionAfterTimeToTarget is this:geoCoordinatesAtTime(timeAtTarget, this:targetPosition).

        if this:subState = SUBSTATE_NONE {
            // Check that the time shifted target point is in a 180° cone.
            if targetPositionAfterTimeToTarget:heading >= 0 and targetPositionAfterTimeToTarget:heading <= 180 {
                set this:subState to SUBSTATE_ORBIT_ADJUSTMENT_INC.
            } else {
                set this:message to "Cannot achieve target orbit inclination!".
                set this:state to STATE_FINISHED.
            }
        } 
        
        if this:subState = SUBSTATE_ORBIT_ADJUSTMENT_INC {
            if abs(this:courseError) < 0.01 {
                set this:throttle to 0.
                set this:message to "Target orbit in inclination achieved.".
                if this:lowDeorbit {
                    set this:subState to SUBSTATE_ORBIT_ADJUSTMENT_DEORBIT_ALTITUDE.
                } else {
                    set this:subState to SUBSTATE_NONE.
                    set this:state to STATE_COAST_TO_DEORBIT.
                }
            } else {
                if this:courseError < 0 {
                    set this:steering to heading(this:surfaceVelocityHeading - 90, 0, 0):vector.
                } else if this:courseError > 0 {
                    set this:steering to heading(this:surfaceVelocityHeading + 90, 0, 0):vector.
                }
                set this:message to "Burning for orbit inclination change.".
                this:alignedAcceleration(abs(this:courseError)*50, 5, 0.01).
            }
        } 
        
        // Optimum maneuver (hohmann transfer) would require us to be on the opposite site of the body.
        // This also would mean, we would need to consider a lot of extra time for target movement.
        // Instead we just lower the orbit to be at "deorbitAltitude" over the target and then switch to vertical descent.
        if this:subState = SUBSTATE_ORBIT_ADJUSTMENT_DEORBIT_ALTITUDE {
            // While burning retrograde we are going to be at the periapsis
            local deorbitTime is TimeSpan(ship:orbit:eta:periapsis - this:timeOfAltitude(this:deorbitAltitude)).
            local deorbitStartTime is time:seconds + deorbitTime:seconds.
            local deorbitPosition is positionAt(ship, deorbitStartTime).
            local altitudeAtDeorbitTime is body:altitudeof(deorbitPosition).
            local deorbitGeoposition is body:geopositionof(deorbitPosition).
            local deorbitGeopositionDistance is this:greatCircleDistance(deorbitGeoposition, this:shipPosition).
            set this:deorbitAltitudeError to altitudeAtDeorbitTime - this:deorbitAltitude.
            local deorbitGeopositionError is deorbitGeopositionDistance - this:surfaceDistance.

            if deorbitTime:seconds <> INFINITE_TIME and abs(deorbitGeopositionError) < 500 and this:deorbitAltitudeError < 500 {
                set this:throttle to 0.
                set this:subState to SUBSTATE_NONE.
                set this:state to STATE_COAST_TO_DEORBIT.
                set this:message to "Target deorbit altitude achieved.".
            } else {
                set this:steering to retrograde:vector.
                this:alignedAcceleration(abs(deorbitGeopositionError)/50).
                set this:message to "Burning for deorbit altitude change.".
            }
        }
    }

    // Wait until we are close to the landing point
    if this:state = STATE_COAST_TO_DEORBIT {
        set this:message to "Preparing de-orbit.".
        set this:throttle to 0.
        set this:steering to heading(this:surfaceVelocityHeading-180, 0, 0):vector.
        local deceleration is max(0.0001, this:availableEngineAcceleration).
        local decelerationBurnTime is TimeSpan((this:surfaceSpeed - this:targetRotationalVelocity) / deceleration).
        local decelerationDistance is 0.5 * availableThrust / ship:mass * (decelerationBurnTime:seconds)^2.
        set this:deorbitDistance to decelerationDistance.// * 1.02. // Include a 2% safety margin

        if this:surfaceDistance < this:deorbitDistance {
            set this:message to "Starting de-orbit.".
            set this:state to STATE_DEORBIT.
            set this:steering to heading(this:surfaceVelocityHeading-180, 0, 0):vector.
        }
    }

    // Burn retrograde until orbit intersection with surface is close to target point
    // or orbit retrograde is getting close to vertical.
    if this:state = STATE_DEORBIT {
        this:stageOnDemand().

        local lastImpactPosition is this:impactPredictor:averagedEstimatedImpactPosition().
        set this:impactPosition to lastImpactPosition:position.
        set this:impactTime to lastImpactPosition:time.

        set this:errorCorrection to this:landPid:update(time:seconds, this:courseError).

        local impactToTargetDistance is (this:impactPosition - this:targetPosition:position):mag.
        local impactGeoposition is body:geopositionof(this:impactPosition).
        local impactGeopositionDistance is this:greatCircleDistance(impactGeoposition, this:shipPosition).
        local deorbitImpactError is impactGeopositionDistance - this:surfaceDistance.

        set this:message to "Deorbit - Error: " + kate_prettyDistance(impactToTargetDistance, 1).
        set this:steering to (retrograde:vector + 10 * this:errorCorrection * ship:facing:starvector):normalized.
        this:alignedAcceleration(max(this:surfaceSpeed / 10, deorbitImpactError / 200)).

        // TODO: Express this in something relative, e.g. to height
        if (deorbitImpactError < 2000 and impactToTargetDistance < 2000) or this:surfaceSpeed < 10 {
            set this:throttle to 0.
            set this:steering to srfRetrograde:vector.
            set this:state to STATE_LAND.
            set this:subState to SUBSTATE_LAND_ALIGN.
        }
    }

    if this:state = STATE_LAND {
        this:stageOnDemand().

        local lastImpactPosition is this:impactPredictor:averagedEstimatedImpactPosition().
        set this:impactPosition to lastImpactPosition:position.
        set this:impactTime to lastImpactPosition:time.

        local impactToTargetDistance is (this:impactPosition - this:targetPosition:position):mag.
        set this:message to "Land - Error: " + kate_prettyDistance(impactToTargetDistance, 1).

        // Calculate suicide burn altitude
        local engineDeceleration is max(0.0001, this:availableEngineAcceleration).
        local atmDeceleration is 0.
        if this:hasAtmosphere {
            // Assume Area = 5, Cd = 0.3
            set atmDeceleration to 0.5 * this:atmDensityAt(ship:altitude / 2) * 5 * 0.3 * (ship:verticalspeed)^2 / ship:mass.
        }
        local totalDeceleration is engineDeceleration + atmDeceleration - this:gravity.
        set this:suicideBurnTime to TimeSpan(max(0, -ship:verticalspeed / totalDeceleration)).
        set this:suicideBurnAltitude to 0.5 * totalDeceleration * (this:suicideBurnTime:seconds)^2.

        // Perform precision steering based on actual position of ship and target using the target movement as well
        local upVector is this:shipClearAltitude * heading(0,90,0):vector.
        local targetVector is this:targetPosition:position - ship:position.
        local impactVector is this:impactPosition - ship:position.
        local errorVector is targetVector - impactVector.
        local angleOfError is vAng(impactVector, targetVector).
        set this:errorCorrection to this:landPid:update(time:seconds, angleOfError).

        // Make sure vulnerable stuff is stowed away.
        this:setLandingConfiguration(true).

        if this:subState = SUBSTATE_LAND_ALIGN {
            if angleOfError < 0.01 {
                set this:throttle to 0.
                set this:steering to ship:srfretrograde:vector:normalized.
                set this:message to "Suicide burn - coasting           ".
            } else {
                local steeringVector is ship:srfretrograde:vector:normalized + 200 * abs(this:errorCorrection) * errorVector:normalized.
                this:alignedThrottle(min(1, abs(this:errorCorrection))).
                set this:steering to steeringVector:normalized.
                set this:message to "Suicide burn - aligning            ".
            }

            if this:wallTemperature > MAX_WALL_TEMP {
                this:alignedThrottle(1).
                set this:message to "Suicide burn - wall temperature protection".
            }

            if this:shipClearAltitude < this:suicideBurnAltitude + 500 {
                set this:subState to SUBSTATE_LAND_SUICIDE_BURN.
            }
        } 

        if this:subState = SUBSTATE_LAND_SUICIDE_BURN {
            local impactTimeMargin is this:impactTime:seconds - time:seconds.
            if impactTimeMargin < 20 {
                set this:message to "Suicide burn - break burning limited: " + kate_prettyTime(TimeSpan(impactTimeMargin)).
                this:finalSteering(ship:srfretrograde:vector:normalized + abs(this:errorCorrection) * errorVector:normalized, -50).
            } else {
                set this:message to "Suicide burn - break burning full: " + kate_prettyTime(TimeSpan(impactTimeMargin)).
                this:finalSteering(ship:srfretrograde:vector:normalized + abs(this:errorCorrection) * errorVector:normalized, -5).
            }

            if impactTimeMargin > 30 or this:shipClearAltitude < 500 {
                set this:subState to SUBSTATE_LAND_FINAL.
            }
        } 

        if this:subState = SUBSTATE_LAND_FINAL {
            if this:shipClearAltitude < 10 {
                set this:message to "Final - land                         ".
                this:finalSteering(heading(0, 90, 0), -2).
            } else if this:shipClearAltitude < 50 {
                set this:message to "Final - last 50 m                    ".
                this:finalSteering(heading(0, 90, 0), -5).
            } else if this:shipClearAltitude < 500 {
                set this:message to "Final - last 500 m                   ".
                this:finalSteering(upVector:normalized + 0.5 * abs(this:errorCorrection) * errorVector:normalized, -10).
            } else if this:shipClearAltitude < (this:suicideBurnAltitude + 500) {
                set this:message to "Final - last 1000 m                  ".
                this:finalSteering(upVector:normalized + 1 * abs(this:errorCorrection) * errorVector:normalized, -20).
            } else {
                set this:message to "Final - coasting                     ".
                set this:steering to ship:srfretrograde:vector:normalized.
                set this:throttle to 0.
            }
        }

        if this:shipClearAltitude < 500 {
            this:ownship:deployGear(true).
        }

        if ship:status = "LANDED" or ship:status = "SPLASHED" {
            set this:message to "Landing completed.".
            set this:state to STATE_FINISHED.
        }
    }

    if this:state = STATE_FINISHED {
        this:setLandingConfiguration(false).
        set this:throttle to 0.
        this:finish().
    }
}

local function KatePointLandTask_finalSteering {
    parameter   this,
                steeringVector, // Vector or Direction
                vertialVelocityGoal.
    
    if (steeringVector:istype("Direction")) {
        set this:steering to steeringVector:vector:normalized.
    } else if (steeringVector:istype("Vector")) {
        set this:steering to steeringVector:normalized.
    } else {
        this:throw("Illegal type of steeingVector").
    }
    set this:finalPid:setPoint to vertialVelocityGoal.
    this:alignedAcceleration(this:finalPid:update(time:seconds, ship:verticalspeed)).
}

local function KatePointLandTask_stageOnDemand {
    parameter   this.
    
    if (maxThrust <= 0 or this:ownship:hasDepletedEnginesInCurrentStage()) and stage:ready { 
        stage.
    }
}

// Haversine formula for creat circle distance on spherical bodies.
local function KatePointLandTask_greatCircleDistance {
    parameter this, 
              pos1, pos2. // GeoCoordinates
              
    local lat1 is pos1:lat.
    local lng1 is pos1:lng.
    local lat2 is pos2:lat.
    local lng2 is pos2:lng.
    local radius is ship:body:radius.

    local havLat is sin((lat2-lat1)/2)^2.
    local havLng is cos(lat1) * cos(lat2) * sin((lng2-lng1)/2)^2.
    local havTerm is arcSin(sqrt(havLat + havLng)) * constant:degtorad.

    return 2 * radius * havTerm. 
}

// Haversine formula for creat circle distance on spherical bodies.
local function KatePointLandTask_greatCircleAzimuth {
    parameter this, 
              pos1, pos2. // GeoCoordinates
              
    local lat1 is pos1:lat.
    local lng1 is pos1:lng.
    local lat2 is pos2:lat.
    local lng2 is pos2:lng.
    local deltalng is lng2-lng1.

    return arcTan2(sin(deltalng) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltalng)). 
}

// Returns the geo coordinates at a given time adjusting for planetary rotation over time.
local function KatePointLandTask_geoCoordinatesAtTime {	
	parameter this,
              posTime, // TimeStamp
              posLatLng. // GeoCoordinates

	local localBody is ship:body.
    // the number of radians the body will rotate in one second (negative if rotating counter clockwise when viewed looking down on north
	local rotationalDir is vdot(localBody:north:forevector, localBody:angularvel). 
	local timeDif is posTime - time:seconds.
	local longitudeShift is rotationalDir * timeDif:seconds * constant:radtodeg.
	local newLng is mod(posLatLng:lng + longitudeShift ,360).
	if newLng < - 180 { set newLng to newLng + 360. }
	if newLng > 180 { set newLng to newLng - 360. }

	return latlng(posLatLng:lat, newLng).
}

local function KatePointLandTask_surfaceHeading {
    parameter this.

    local vel_x is vDot(heading(90, 0):vector, ship:srfprograde:vector).
    local vel_y is vDot(heading( 0, 0):vector, ship:srfprograde:vector).

    return mod(arcTan2(vel_x, vel_y)+360, 360).
}

local function KatePointLandTask_alignedAcceleration {
    parameter this,
              desiredAcceleration,
              allowedDeviation is 90,
              offAlignmentThrottleRatio is 0.2.

    local maxAcceleration is ship:availablethrust / ship:mass.
    if (maxAcceleration > 0) {
        local neededThrottle is min(1, desiredAcceleration / maxAcceleration).
        this:alignedThrottle(neededThrottle, allowedDeviation, offAlignmentThrottleRatio).
    } else {
        set this:message to "No thrust available!".
        //set this:state to STATE_FINISHED.
    }
}

local function KatePointLandTask_alignedThrottle {
    parameter this,
              desiredThrottle,
              allowedDeviation is 90,
              offAlignmentThrottleRatio is 0.01.

    local steeringError is vAng(ship:facing:forevector, this:steering).
    if abs(steeringError) < allowedDeviation {
        set this:throttle to min(1, desiredThrottle * cos(steeringError)).
    } else {
        set this:message to "Aligning thrust vector...".
        set this:throttle to max(0.01, offAlignmentThrottleRatio * desiredThrottle).
    }
}

// Based on Kepler equation, time from periapsis to given radius.
// t(r) = sqrt(a3 / μ) * [2 * atan(sqrt((r - a * (1 - e)) / (a * (1 + e) - r))) - sqrt(e2 - (1 - r / a)2 )]
local function KatePointLandTask_timeOfAltitude {
    parameter this,
              targetAltitude.

    local pe is ship:orbit:periapsis + ship:body:radius.
    local ap is ship:orbit:apoapsis + ship:body:radius.
    local a is ship:orbit:semimajoraxis.
    local b is ship:orbit:semiminoraxis.
    local e is ship:orbit:eccentricity.
    local radius is targetAltitude + ship:body:radius.
    local mu is ship:body:mu.

    if radius <= ap and radius >= pe {
        return sqrt((a^3)/mu) * (2 * arcTan(sqrt((radius - a * (1 - e)) / (a * (1 + e) - radius)))*constant:degtorad - sqrt(e^2 - (1 - radius / a)^2)).
    } else {
        return INFINITE_TIME.
    }
}

// Returns TimeSpan to next occurence of given targetAltitude on the elliptical orbit
local function KatePointLandTask_timeBetweenAltitudes {
    parameter this,
              firstAltitude,
              targetAltitude.

    local t1 is this:timeOfAltitude(firstAltitude).
    local t2 is this:timeOfAltitude(targetAltitude).

    print kate_prettyTime(TimeSpan(t1)) at (40, 33).
    print kate_prettyTime(TimeSpan(t2)) at (40, 34).

    return TimeSpan(t2-t1).
}

local function KatePointLandTask_atmDensityAt {
     parameter this,
               pAltitude.

    local atmMolMass is ship:body:atm:molarmass.
    local atmSpecGasConst is 8.3144598 / atmMolMass.
    local atmTemp to ship:body:atm:altitudetemperature(pAltitude).
    local atmPres is ship:body:atm:altitudepressure(pAltitude).
    local atmDensity is 0.
    if (atmTemp > 0) {
        set atmDensity to atmPres / (atmSpecGasConst * atmTemp) * constant:atmtokpa.
    }
    return atmDensity.
}

local function KatePointLandTask_setLandingConfiguration {
    parameter this,
              state. // boolean
    
    if (not this:landingConfiguration and state) or (this:landingConfiguration and not state) {
        if this:hasAtmosphere {
            local airbrakes is this:ownship:detectAirbrakes().
            this:ownship:deployAirbrakes(airbrakes, state, state).
            set this:landingConfiguration to state.
            if state {panels off.} else {panels on.}.
        }
    }
    //this:ownship:deployChutes(state).
}