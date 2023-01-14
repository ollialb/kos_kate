@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/library/kate_ship").

local STATE_APPROACH_INIT is "INIT".
local STATE_APPROACH_ALIGN is "ALGN".
local STATE_APPROACH_ACCEL is "ACCL".
local STATE_APPROACH_COAST is "COST".
local STATE_APPROACH_DECEL is "DECL".
local STATE_APPROACH_APPR is "APPR".
local STATE_APPROACH_DONE is "DONE".

local DEFAULT_APPROACH_THROTTLE is 0.1. // 10%
local DEFAULT_CLOSING_SPEED is 10.0. // m/s
local FINAL_TARGET_DISTANCE is 10.0. // m
local FINAL_TARGET_VELOCITY is 2.0. // m/s

global function KateThrusterSteering {
    parameter pTarget, // Orbitable
              pTargetOffset is V(0, 0, 0), 
              pMaxThrottle is DEFAULT_APPROACH_THROTTLE,
              pClosingSpeed is DEFAULT_CLOSING_SPEED,
              pDrawVecs is false.

    local this is KateObject("KateThrusterSteering", "ThrusterSteering").

    // Init target
    set this:target to pTarget.
    set this:targetVessel to choose pTarget:ship if pTarget:isType("Part") else pTarget.
    set this:approachOffset to pTargetOffset.
    set this:maxThrottle to pMaxThrottle.
    set this:maxClosingSpeed to pClosingSpeed.
    set this:drawVecs to pDrawVecs.

    set this:decelerationTime to 0.
    set this:maxCoastingDistance to 0.
    set this:distance to 0.
    set this:direction to 0.
    set this:throttle to 0.
    set this:approachPoint to V(0, 0, 0).
    set this:relativeVelocity to V(0, 0, 0).
    set this:relativePosition to V(0, 0, 0).
    set this:interceptVector to V(0,0,0).
    set this:interceptAngle to 0.
    set this:finished to false.
    set this:state to STATE_APPROACH_INIT.

    set this:velocityPid     to pidLoop(0.30, 0.0,   0.0, -pClosingSpeed, pClosingSpeed).
    set this:throttlePid     to pidLoop(0.05, 0.001, 0.001, 0, 1).
    set this:accelerationPid to pidLoop(0.5,  0.001, 0.001).

    this:def("uiContent", KateThrusterSteering_uiContent@).
    this:def("onCyclic", KateThrusterSteering_onCyclic@).
    this:def("alignedAcceleration", KateThrusterSteering_alignedAcceleration@).

    return this.
}

local function KateThrusterSteering_uiContent {
    parameter   this,
                result. // list

    result:add("M_ENG STRNG [" + this:state + "]: '" + (this:target):name + "'").
    result:add(kate_datum("ANG", UNIT_DEGREE, this:interceptAngle,1)         + kate_datum("VEL", UNIT_SPEED, this:relativeVelocity:mag,1)).
}

local function KateThrusterSteering_onCyclic {
    parameter   this.

    // Basic approach is to come to a stop at the destination point and use low throttle/velocity
    // maneuvering to approach this point. If we are close enough we just eliminate the residual velocity.
    //   

    // Approach point is current position plus offset
    set this:approachPoint to (this:target):position + this:approachOffset.
    // Target position vector relative to ownship
    set this:relativePosition to (this:approachPoint - ship:position).
    set this:relativeVelocity to ((this:targetVessel):velocity:orbit - ship:velocity:orbit).
    // Distance and direction to aim point
    set this:distance to this:relativePosition:mag.
    set this:direction to lookDirUp(this:approachPoint, ship:velocity:orbit).

    if this:state = STATE_APPROACH_INIT {
        set this:interceptVector to this:relativePosition.
        set this:throttle to 0.
        set this:state to STATE_APPROACH_APPR.
        
        lock steering to this:interceptVector.
        lock throttle to this:throttle.
        
        if this:drawVecs {
            clearVecDraws().
            vecDraw({return ship:position.}, {return this:relativeVelocity.}, rgb(0, 1, 0), "DV", 10, true, 0.1, true, true).
            vecDraw({return ship:position.}, {return this:interceptVector.}, rgb(0, 0, 1), "IC", 10, true, 0.1, true, true).
            vecDraw({return ship:position.}, {return this:approachPoint.}, rgb(1, 0, 0), "TGT", 1, true, 0.1, true, true).
        }
    } else if this:state = STATE_APPROACH_APPR {
        if this:distance < FINAL_TARGET_DISTANCE and this:relativeVelocity:mag < FINAL_TARGET_VELOCITY {
            set this:throttle to 0.
            set this:state to STATE_APPROACH_DONE.
        } else {
            // Calculate closing velocity proportional to current distance.
            local requiredVelocity is this:relativePosition / 30.
            // Limit requested velocity
            if (requiredVelocity:mag > this:maxClosingSpeed) {
                set requiredVelocity to requiredVelocity:normalized * this:maxClosingSpeed.
            }
            // Total velocity need is closing velocity minus current velocity.
            // Since relativeVelocity is for target to use, we need to invert it (+ sign below).
            local velocityError is requiredVelocity + this:relativeVelocity.
            local requiredAcceleration is this:accelerationPid:update(time:seconds, -velocityError:mag).

            // Figure out, where to point the ship
            set this:interceptAngle to vectorAngle(requiredVelocity, this:relativeVelocity).
            if (requiredAcceleration < 0) {
                set this:interceptVector to -velocityError.
            } else {
                set this:interceptVector to velocityError.
            }

            // Set throttle & direction
            this:alignedAcceleration(requiredAcceleration, 1, 0).
        }
    } else if this:state = STATE_APPROACH_DONE {
        clearVecDraws().
        set this:finished to true.
    }
}

local function KateThrusterSteering_alignedAcceleration {
    parameter this,
              desiredAcceleration, // m/s^2
              alignmentAngle is 1, // °
              alignmentThrottle is 0.01. // 5%

    local steeringError is vAng(ship:facing:forevector, this:interceptVector).
    if abs(steeringError) < alignmentAngle {
        local desiredThrottle is desiredAcceleration / ship:mass.
        set this:throttle to desiredThrottle.
    } else {
        set this:throttle to alignmentThrottle.
    }
}