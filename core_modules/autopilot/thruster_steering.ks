@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/library/kate_ship").

local STATE_APPROACH_INIT is "InitApproach".
local STATE_APPROACH_ALIGN is "Aligning".
local STATE_APPROACH_ACCEL is "Accelerate".
local STATE_APPROACH_COAST is "Coasting".
local STATE_APPROACH_DECEL is "Decelerate".
local STATE_APPROACH_DONE is "ApproachDone".

local DEFAULT_APPROACH_THROTTLE is 0.1. // 10%
local DEFAULT_CLOSING_SPEED is 20.0. // m/s

global function KateThrusterSteering {
    parameter pTarget, // Orbitable
              pTargetOffset is V(0, 0, 0), 
              pMaxThrottle is DEFAULT_APPROACH_THROTTLE,
              pClosingSpeed is DEFAULT_CLOSING_SPEED,
              pDrawVecs is false.

    local this is KateObject("KateThrusterSteering", "ThrusterSteering").

    // Init target
    set this:target to pTarget.
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

    this:def("uiContent", KateThrusterSteering_uiContent@).
    this:def("onCyclic", KateThrusterSteering_onCyclic@).

    return this.
}

local function KateThrusterSteering_uiContent {
    parameter   this,
                result. // list

    result:add("Main Engine Steering: " + this:state + " to '" + (this:target):name + "'").
    result:add(("DX     :  " + round(this:relativePosition:x,1) + " m"):padright(20)  + "VX     : " + round(this:relativeVelocity:x,1) + " m/s").
    result:add(("DY     :  " + round(this:relativePosition:y,1) + " m"):padright(20)  + "VY     : " + round(this:relativeVelocity:y,1) + " m/s").
    result:add(("DZ     :  " + round(this:relativePosition:z,1) + " m"):padright(20)  + "VZ     : " + round(this:relativeVelocity:z,1) + " m/s").
    result:add(("IcAng  :  " + round(this:interceptAngle,1)     + " °"):padright(20)  + "AppVel : " + round(this:relativeVelocity:mag,1)   + " m/s").
    result:add(("Throtl :  " + round(this:throttle*100,0)       + " %"):padright(20)  + "AppVel : " + round(this:relativeVelocity:mag,1)   + " m/s").
    result:add(("DeclT  :  " + round(this:decelerationTime,1)   + " s"):padright(20)  + "MCD    : " + round(this:maxCoastingDistance,1)   + " m").
}

local function KateThrusterSteering_onCyclic {
    parameter   this.

    // Approach point is current position plus offset
    set this:approachPoint to (this:target):position + this:approachOffset.
    // Target position vector relative to ownship
    set this:relativePosition to (this:approachPoint - ship:position).
    set this:relativeVelocity to ((this:target):velocity:orbit - ship:velocity:orbit).
    // Distance and direction to aim point
    set this:distance to this:relativePosition:mag.
    set this:direction to lookDirUp(this:approachPoint, ship:velocity:orbit).
    // Intercept vector
    set this:interceptVector to this:direction:forevector*this:maxClosingSpeed + this:relativeVelocity.
    set this:interceptAngle to vectorAngle(this:interceptVector, ship:facing:forevector).

    if this:drawVecs {
        clearVecDraws().
        local posVec2 is vecDraw(ship:position, -this:relativeVelocity, rgb(0, 1, 0), "RVel", 10, true, 0.1, true, true).
        local posVec3 is vecDraw(ship:position, this:interceptVector, rgb(0, 0, 1), "Icept", 10, true, 0.1, true, true).
    }

    if this:state = STATE_APPROACH_INIT {
        // Steer directly to target
        lock steering to this:interceptVector.
        lock throttle to this:throttle.
        set this:throttle to 0.
        set this:state to STATE_APPROACH_ALIGN.
    } else if this:state = STATE_APPROACH_ALIGN {
        // Wait for alignment
        if this:interceptAngle < 1.0 {
            set this:state to STATE_APPROACH_ACCEL.
        }
    } else if this:state = STATE_APPROACH_ACCEL {
        if this:relativeVelocity:mag < this:maxClosingSpeed {
            set this:throttle to this:maxThrottle.
        } else {
            // Coast and turn around
            local acceleration is availableThrust * this:maxThrottle / mass.
            set this:decelerationTime to this:relativeVelocity:mag / acceleration.
            set this:maxCoastingDistance to 0.5 * acceleration * this:decelerationTime^2.
            set this:throttle to 0.
            lock steering to this:relativeVelocity.
            set this:state to STATE_APPROACH_COAST.
        }
    } else if this:state = STATE_APPROACH_COAST {
        if this:distance < this:maxCoastingDistance {
            set this:throttle to this:maxThrottle.
            set this:state to STATE_APPROACH_DECEL.
        }
    } else if this:state = STATE_APPROACH_DECEL {
        if this:relativeVelocity:mag < 1.0 {
            set this:state to STATE_APPROACH_DONE.
            set this:throttle to 0.
        }
    } else if this:state = STATE_APPROACH_DONE {
        set this:finished to true.
    }
}