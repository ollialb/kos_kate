@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/library/kate_atmosphere").
include ("kate/library/kate_time_util").
include ("kate/library/kate_dist_util").
include ("kate/library/kate_averaged_value").

local MAX_AOA is 25.
local MAX_CLIMB_ANGLE is 60.
local MIN_CLIMB_ANGLE is -25.
local MAX_BANK_ANGLE is 45.
local BANK_GAIN is 3.
local MIN_ROLL_HEIGHT is 10.
local YAW_ANGLE_ERROR_LIMIT is 30.
local YAW_ROLL_ERROR_LIMIT is 5.
local YAW_TARGET_ROLL_LIMIT is 15.

// Issue to solve:
// - What is an upward lift "generator"
// -- use a kos tag to mark parts?
// - What to control
// -- max rpm
// -- blade angle
// -- aoa of blade

global function KateVtolAutopilotTask {
    local this is KateCyclicTask("KateVtolAutopilotTask", "VTPLT", 0.01).

    this:declareParameter("heading",  "0",    "Heading [°]: ").
    this:declareParameter("altitude", "5000", "Altitude [m]: ").
    this:declareParameter("speed",    "200",  "Speed [m/s]: ").

    this:override("uiContent", KateVtolAutopilotTask_uiContent@).
    
    this:def("onActivate", KateVtolAutopilotTask_onActivate@).
    this:def("onDeactivate", KateVtolAutopilotTask_onDeactivate@).
    this:def("onCyclic", KateVtolAutopilotTask_onCyclic@).
    this:def("setAfterburners", KateVtolAutopilotTask_setAfterburners@).
    this:def("setAutopilotParameters", KateVtolAutopilotTask_setAfterburners@).

    set this:message to "".
    set this:uiContentHeight to 5.

    set this:ownship to KateShip(ship).
    set this:atmosphere to kate_AtmosphereAt(ship:altitude, ship:airspeed).

    set this:active to true.
    set this:targetAltitude to 0.
    set this:targetSpeed to 200.
    set this:targetHeading to 5000.

    set this:currentAltitude to ship:altitude.
    set this:currentSpeed to ship:airspeed.
    set this:currentHeading to this:ownship:surfaceHeading().
    set this:currentVelocity to ship:velocity:surface.

    set this:currentClimbRate to 0.
    set this:currentHeadingRate to 0.
    set this:currentSpeedRate to 0.

    set this:pitchVelocityPid to pidLoop(0.6, 0.2, 0.5, -10, 20).
    set this:pitchPid to pidLoop(10.2, 0.5, 0.2, -1, 1).

    set this:rollVelocityPid to pidLoop(0.025, 0.0001, 0.01).
    set this:rollPid to pidLoop(0.025, 0.0001, 0.01).

    set this:yawVelocityPid to pidLoop(1, 0, 0.5, -20, 20).
	set this:yawPid to pidLoop(2.0,0,0.2,-1,1).

    set this:throttlePid to pidLoop(0.2, 0.0, 0.0, -100, 100).

    set this:targetRoll to 0.
    set this:targetPitch to 0.
    set this:targetYaw to 0.

    set this:throttle to throttle.
    set this:useAfterburners to true.
    set this:afterburners to this:ownship:activeAfterburners().
    set this:lastAfterburnerChange to time.

    set this:angleOfAttack to 0.
    set this:lastTime to time.

    return this.
}

local function KateVtolAutopilotTask_onActivate {
    parameter this.

    // Preserve current state for now
    set this:targetHeading to this:getNumericalParameter("heading").
    set this:targetAltitude to this:getNumericalParameter("altitude").
    set this:targetSpeed to this:getNumericalParameter("speed").
    lock throttle to this:throttle.
    sas off.
}

local function KateVtolAutopilotTask_onDeactivate {
    parameter this.

    if this:afterburners this:ownship:engageAfterburners(false).
    set ship:control:neutralize to true.
    unlock throttle.
    sas on.
}

local function KateVtolAutopilotTask_uiContent {
    parameter this.

    local result is list().
    local afterBurnerFlag is choose " [AB]" if this:afterburners else "     ".
    result:add(("Tgt Hdg: " + round(this:targetHeading, 2) + " °"):padright(20)          + (" Alt: " + kate_prettyDistance(this:targetAltitude, 1)):padright(20)    + " Spd: " + kate_prettySpeed(this:targetSpeed, 1)).
    result:add("---------------------------------------------------------------------------").
    kate_prettyAtmosphere(kate_AtmosphereAt(ship:altitude, ship:airspeed), result).

    return result. 
}

local function KateVtolAutopilotTask_onCyclic {
    parameter this.

    local upVector is up:vector.
    local surfaceVelocity is velocity:surface.

    set this:stallSpeed to 70. // m/s
    set this:landed to ship:status = "LANDED".
    set this:afterburners to this:ownship:activeAfterburners().

    set this:targetHeading to this:getNumericalParameter("heading").
    set this:targetAltitude to this:getNumericalParameter("altitude").
    set this:targetSpeed to this:getNumericalParameter("speed").

    local lastSpeed is this:currentSpeed.
    local lastHeading is this:currentHeading.
    local lastVelocity is this:currentVelocity.
    local lastAltitude is this:currentAltitude.

    set this:currentVelocity to ship:velocity:surface.
    set this:currentAltitude to ship:altitude.
    set this:currentSpeed to ship:airspeed.
    set this:currentHeading to this:ownship:surfaceHeading().

    local deltaTime is (time - this:lastTime):seconds.
    if (deltaTime = 0) return 0.

    set this:currentClimbRate to ship:verticalSpeed.
    set this:currentHeadingRate to (this:currentHeading - lastHeading) / deltaTime.
    set this:currentSpeedRate to (this:currentSpeed - lastSpeed) / deltaTime.
    set this:currentAccelerationVector to (this:currentVelocity - lastVelocity) / deltaTime.

    // Drag ------------------------------------------------------
    local thrustVector is this:ownship:totalThrust().
	local engineAccelerationVector is thrustVector / ship:mass.
	local dragAccelerationVector is this:currentAccelerationVector - engineAccelerationVector.
	local dragFacingMagnitude is vectorDotProduct(ship:facing:vector, dragAccelerationVector).
	local dragVelocityMagnitude to vectorDotProduct(this:currentVelocity:normalized, dragAccelerationVector).

    // Altitude ------------------------------------------------------
    local altitudeError is this:targetAltitude - this:currentAltitude.
    set this:targetClimbRate to max(-this:currentSpeed, min(this:currentSpeed, altitudeError / 10)).

    // Pitch ----------------------------------------------------------
    // Set target pitch to achive desired climb rate
    set this:targetPitch to 90 - arcCos(this:targetClimbRate / max(0.1, this:currentSpeed)).

    // Heading --------------------------------------------------------
    set this:targetPitch to min(MAX_CLIMB_ANGLE, max(MIN_CLIMB_ANGLE, this:targetPitch)).
    local targetSteering is heading(this:targetHeading, this:targetPitch):vector.
	local velocityPitch is vectorAngle(upVector, surfaceVelocity).
	local steeringPitch is max(velocityPitch - MAX_AOA, min(velocityPitch + MAX_AOA, vectorAngle(upVector, targetSteering))).
	local pitchError is velocityPitch - steeringPitch.
    set this:angleOfAttack to 90 - velocityPitch.

    if this:currentSpeed > this:stallSpeed * 0.7 or not(this:landed) {
		set this:pitchPid:setpoint to this:pitchVelocityPid:update(time:seconds, -pitchError) / (40 + this:currentSpeed / 30).
		set ship:control:pitch to this:pitchPid:update(time:seconds, -vectorDotProduct(vectorExclude(upVector, facing:starvector):normalized, ship:angularvel)).
	} else { 
        set ship:control:pitch to ship:control:pitch * 0.99. 
        this:pitchVelocityPid:reset(). 
    }

    // Roll -----------------------------------------------------------
    // Angle between horizontal components of steering and velocity
    local horizontalAngleError is max(0, vectorAngle(vectorExclude(upVector, targetSteering), vectorExclude(upVector, velocity:surface))).
	if vectorDotProduct(vectorExclude(surfaceVelocity, facing:starvector), targetSteering) < 0 set horizontalAngleError to -horizontalAngleError.
	
	if alt:radar > MIN_ROLL_HEIGHT and pitchError > -5 {
	    set this:targetRoll to min(MAX_BANK_ANGLE, max(-MAX_BANK_ANGLE, horizontalAngleError * BANK_GAIN)).
    } else {
        set this:targetRoll to 0.
    }
	
	local rollError is this:targetRoll - (vectorAngle(facing:starvector, upVector) - 90).
	set this:rollPid:setpoint to (0.5*BANK_GAIN) * rollError / (80 + airspeed / 20).
	set ship:control:roll to this:rollPid:update(time:seconds, -vectorDotProduct(ship:facing:vector, ship:angularvel)).

     // Yaw -----------------------------------------------------------
	local yawAngleError is min(YAW_ANGLE_ERROR_LIMIT, vectorAngle(ship:facing:vector, vectorExclude(facing:topvector, targetSteering))).
    if vectorDotProduct(facing:starvector, targetSteering) < 0 set yawAngleError to -yawAngleError.
    set this:yawPid:setpoint to this:yawVelocityPid:update(time:seconds, -yawAngleError) / (40 + airspeed / 30).

	if this:landed {
		set ship:control:yaw to this:yawPid:update(time:seconds, -vectorDotProduct(facing:topvector, ship:angularvel)).
	}
	else if abs(rollError) < YAW_ROLL_ERROR_LIMIT and abs(this:targetRoll) < YAW_TARGET_ROLL_LIMIT {
		set ship:control:yaw to this:yawPid:update(time:seconds, vectorDotProduct(facing:topvector, ship:angularvel)).
	}
	else set ship:control:yaw to 0.

    // Speed & Throttle -------------------------------------------------
    local forwardSpeed is vdot(ship:facing:vector, velocity:surface).
    local speedError is forwardSpeed - this:targetSpeed.
	
	if (brakes and speedError > 0) or this:targetSpeed = 0 {
        set this:throttle to 0.
        this:setAfterburners(false, true).
	} else {
        set this:throttlePid:setpoint to this:targetSpeed.
        local targetThrottle is this:throttlePid:update(time:seconds, this:currentSpeed).
        set this:throttle to max(0, min(1, targetThrottle)).

        local relativeSpeedError is -speedError / this:currentSpeed.
        this:setAfterburners(targetThrottle > 5, targetThrottle < 0).
	}
    
    // Last thing to do
    set this:lastTime to time.
}

local function KateVtolAutopilotTask_setAfterburners {
    parameter this, enableCrit, disableCrit.
    
    local afterBurnerCanChange is (time - this:lastAfterburnerChange):seconds > 5.
    // print (time - this:lastAfterburnerChange):seconds at (30, 34).
    if afterBurnerCanChange and enableCrit and not this:afterburners and this:useAfterburners { 
        this:ownship:engageAfterburners(true).  
        set this:lastAfterburnerChange to time.
        this:throttlePid:reset().
    }
    if afterBurnerCanChange and disableCrit and this:afterburners { 
        this:ownship:engageAfterburners(false). 
        set this:lastAfterburnerChange to time. 
        this:throttlePid:reset().
    }
}