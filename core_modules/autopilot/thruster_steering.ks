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

    result:add("M_ENG STRNG [" + this:state + "]: '" + (this:target):name + "'").
    result:add(kate_datum("DX ", UNIT_DISTANCE, this:relativePosition:x,1)   + kate_datum("VX ", UNIT_VELOCITY, this:relativeVelocity:x,1)).
    result:add(kate_datum("DY ", UNIT_DISTANCE, this:relativePosition:y,1)   + kate_datum("VY ", UNIT_VELOCITY, this:relativeVelocity:y,1)).
    result:add(kate_datum("DZ ", UNIT_DISTANCE, this:relativePosition:z,1)   + kate_datum("VZ ", UNIT_VELOCITY, this:relativeVelocity:z,1)).
    result:add(kate_datum("ANG", UNIT_DEGREE, this:interceptAngle,1)         + kate_datum("VEL", UNIT_VELOCITY, this:relativeVelocity:mag,1)).
    result:add(kate_datum("T_D ", UNIT_SECONDS, this:decelerationTime,1)     + kate_datum("MCD", UNIT_DISTANCE, this:maxCoastingDistance,1)).
}

local function KateThrusterSteering_onCyclic {
    parameter   this.

    // Basic approach is to have three maneuvers
    //   
    //    TGT
    //    P^  \
    //     |    V
    //     |
    //     |
    //    SHP --> I
    //
    // 1) Choose intercept course to estimated position using a given delta-v
    // The basic integral of distance over acceleration is for the accel and decel segments
    //       S_acc = 1/2 a I t_burn^2
    //       S_dec = 1/2 a I t_burn^2
    // The total distance covered after accel burn, coasting and decel burn is 
    //       S_acc + S_dec + S_coast = 2 1/2 a I t_burn^2 + a I t_burn t_coast = a I t_burn (t_burn + t_coast)
    //
    // Assuming we normalize the coordinate system so that the ship's initial position and speed are zero, we get
    // the target and ship positions at intercept time ti as
    //       P_target_ti = P0 + V (2 t_burn + t_coast)
    //       P_ship_ti = a I t_burn (t_burn + t_coast)
    //
    // The condition for interception is then
    //       p_target(t) = p_ship(t)
    // <=>   P + V (2 t_burn + t_coast) = a I t_burn (t_burn + t_coast)
    // <=>   P + V (2 t_burn + t_coast) - a I t_burn (t_burn + t_coast) = 0    (1)
    //
    // The delta_v we want to invest is a user parameter and with that we get a burn time as
    //       t_burn = 0.5 delta_v / a
    // If we enter this into (1) we get with V = v_target, d = deltav, c = t_coast, p = p_target_0
    //       P + V (d / a + c) - a I 0.5 d / a (0.5 d / a + c) = 0
    // <=>   P + V d / a + V c - 0.25 I d^2 / a + 0.5 I d c = 0
    //
    // We also need to turn the ship midways and therefore have the constraint
    //       c >= TURN_TIME
    // and therefore get an entry constraint for our maneuver
    //       (-4 a p_target_0 + delta_v^2 - 2 delta_v v_target)/(4 a v_target - 2 a delta_v) >= TURN_TIME 

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