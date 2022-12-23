@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/library/kate_ship").

local STATE_INIT is "Init".
local STATE_STEER is "Steering".
local STATE_STEER_FINAL is "SteeringFinal".
local STATE_DONE is "Done".

local DECEL_DIST is 20.0. // m
local MAX_SPEED is 1.0. // m/s
local MAX_STEERING_ERROR is 0.1. // m
local MIN_FINAL_DISTANCE is 0.1. // m
local FINAL_STEERING_OFFSET_FACTOR is 10. // no unit

global function KateRcsSteering {
    parameter pTarget, // Orbitable
              pOwnPort is 0,
              pTargetOffset is V(0, 0, 0),
              pDrawVecs is false.

    local this is KateObject("KateRcsSteering", "RcsSteering").

    // Init target
    set this:target to pTarget.
    set this:ownPort to pOwnPort.
    set this:approachOffset to pTargetOffset * FINAL_STEERING_OFFSET_FACTOR.
    set this:finalOffset to pTargetOffset.
    set this:drawVecs to pDrawVecs.

    set this:distance to 0.
    set this:direction to 0.
    set this:approachPoint to V(0, 0, 0).
    set this:relativeVelocity to V(0, 0, 0).
    set this:relativePosition to V(0, 0, 0).
    set this:steeringVector to V(0, 0, 0).
    set this:steeringAngle to 0.
    set this:rcsAvailableThrust to V(0, 0, 0).
    set this:upError to 0.
    set this:foreError to 0.
    set this:stbdError to 0.
    set this:upVel to 0.
    set this:foreVel to 0.
    set this:stbdVel to 0.
    set this:finished to false.
    set this:state to STATE_INIT.

    this:def("uiContent", KateRcsSteering_uiContent@).
    this:def("onCyclic", KateRcsSteering_onCyclic@).

    return this.
}

local function KateRcsSteering_uiContent {
    parameter   this,
                result. // list

    local portStatus is choose this:ownPort:state if this:ownPort <> 0 else "N/A".

    result:add("RCS: " + this:state + " to '" + (this:target):name + "'").
    result:add(("Dist   :  " + round(this:distance,1) + " m"):padright(14)   + "Port   : " + portStatus). 
    result:add(("DUp    :  " + round(this:upError,1) + " m"):padright(14)    + "VUp    : " + round(this:upVel,1) + " m/s").
    result:add(("DFore  :  " + round(this:foreError,1) + " m"):padright(14)  + "VFore  : " + round(this:foreVel,1) + " m/s").
    result:add(("DStbd  :  " + round(this:stbdError,1) + " m"):padright(14)  + "VStbd  : " + round(this:stbdVel,1) + " m/s").
    result:add(("StAng  :  " + round(this:steeringAngle,1)      + " °"):padright(14)  + "AppVel : " + round(this:relativeVelocity:mag,1)   + " m/s").
    result:add("RCSThr :  " + this:rcsAvailableThrust + " kN").
}

local function KateRcsSteering_onCyclic {
    parameter   this.
    
    local targetVelocity is choose this:target:velocity if this:target:isType("Vessel") else this:target:ship:velocity.

    // Approach point is current position plus offset
    set this:approachPoint to (this:target):position + this:approachOffset.
    // Target position vector relative to ownship
    set this:relativePosition to (this:approachPoint - ship:position).
    set this:relativeVelocity to (targetVelocity:orbit - ship:velocity:orbit).
    // Distance and direction to aim point
    set this:distance to this:relativePosition:mag.
    set this:direction to lookDirUp(this:approachPoint, ship:velocity:orbit).
    // Steering Vector is inverse of target facing vector
    set this:steeringVector to -this:target:facing:forevector.
    set this:steeringAngle to vectorAngle(this:steeringVector, ship:facing:forevector).

    if this:state = STATE_INIT {
        // Steer directly to target
        lock steering to this:steeringVector.
        set this:throttle to 0.
        set this:state to STATE_STEER.
        local rcsParts is list().
        list RCS in rcsParts.
        for rcsPart in rcsParts {
            local thrustKn is rcsPart:availablethrust.
            local rcsVector is V(choose thrustKn if rcsPart:foreEnabled else 0,
                                 choose thrustKn if rcsPart:topEnabled else 0,
                                 choose thrustKn if rcsPart:starboardEnabled else 0).
            set this:rcsAvailableThrust to this:rcsAvailableThrust + rcsVector.
        }
    } else if this:state = STATE_STEER or this:state = STATE_STEER_FINAL {
        // Steering
        set this:upError to this:relativePosition * facing:upvector.
        set this:foreError to this:relativePosition * facing:forevector.
        set this:stbdError to this:relativePosition * facing:starvector.
        set this:upVel to this:relativeVelocity * facing:upvector.
        set this:foreVel to this:relativeVelocity * facing:forevector.
        set this:stbdVel to this:relativeVelocity * facing:starvector.

        if (abs(this:upError) > MAX_STEERING_ERROR and abs(this:upVel) < MAX_SPEED) {
            local upTargetSpeed is -this:upError / 30.
            local upThrottle is -(upTargetSpeed - this:upVel) / abs(upTargetSpeed).
            set ship:control:top to upThrottle.
        } else {
            set ship:control:top to 0.
        }

        if (abs(this:foreError) > MAX_STEERING_ERROR and abs(this:foreVel) < MAX_SPEED) {
            local foreTargetSpeed is -this:foreError / 60.
            local foreThrottle is -(foreTargetSpeed - this:foreVel) / abs(foreTargetSpeed).
            set ship:control:fore to foreThrottle.
        } else {
            set ship:control:fore to 0.
        }

        if (abs(this:stbdError) > MAX_STEERING_ERROR and abs(this:stbdVel) < MAX_SPEED) {
            local stbdTargetSpeed is -this:stbdError / 30.
            local stbdThrottle is -(stbdTargetSpeed - this:stbdVel) / abs(stbdTargetSpeed).
            set ship:control:starboard to stbdThrottle.
        } else {
            set ship:control:starboard to 0.
        }
        
        // Termination criterion
        if this:state = STATE_STEER and (abs(this:upError) < MIN_FINAL_DISTANCE and abs(this:stbdError) < MIN_FINAL_DISTANCE) {
            set this:approachOffset to this:finalOffset.
            set this:state to STATE_STEER_FINAL.
        }
        if this:distance < MIN_FINAL_DISTANCE or (this:ownPort <> 0 and (this:ownPort:state = "PreAttached" or this:ownPort:state:startsWith("Docked"))) {
            set this:state to STATE_DONE.
        }
    } else if this:state = STATE_DONE {
        set ship:control:neutralize to true.
        set this:finished to true.
    }
}