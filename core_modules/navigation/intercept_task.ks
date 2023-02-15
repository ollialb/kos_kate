@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

// Creates two maneuver nodes for a Hohmann transfer intercept to a target in another orbit around the same body.
global function KateInterceptTask {
    local this is KateSingleShotTask("KateInterceptTask", "INTCP").

    this:declareParameter("target", "", "Target vessel name: ").

    this:override("uiContent", KateInterceptTask_uiContent@).
    this:override("performOnce", KateInterceptTask_performOnce@).

    this:def("createNodes", KateInterceptTask_createNodes@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateInterceptTask_uiContent {
    parameter   this.
    local result is list().

    local targetVessel is target.
    result:add("Intercept vessel " + targetVessel:name + ": " + this:message).

    return result.
}

local function KateInterceptTask_performOnce {
    parameter   this.

    local targetVessel is target.
    this:createNodes(targetVessel).
}

local function KateInterceptTask_createNodes {
    parameter   this,
                targetVessel.

    // PROPERTIES OF TRANSFER ELLIPSE -----------------------------
    // Semi major axis of transfer ellipse
    local transferSMA is (max(apoapsis,target:apoapsis)+min(periapsis,target:periapsis))/2+body:radius.

    // Time for half an ellipse turn
    local transferTime is sqrt(4*constant:pi^2*transferSMA^3/constant:g/body:mass)/2.

    // Phase angle at point of intercept with target
    local reqPhaseAngle is 180-360/target:orbit:period*transferTime.

    // Current phase angle of ownship
    local shipAngle is obt:lan+obt:argumentofperiapsis+obt:trueanomaly.

    // Current phase angle of target
    local targetAngle is target:obt:lan+target:obt:argumentofperiapsis+target:obt:trueanomaly.

    // Phaseangle to bridge
    local phaseAngle is targetAngle-shipAngle-360*floor((targetAngle-shipAngle)/360).

    // Rate at which the phase angle closes
    local phaseAngleRate is 360/target:orbit:period-360/orbit:period.

    // Do we need to ascent or descent?
    local dir is 0.
    local dAngle is 0.
    if orbit:semimajoraxis<target:orbit:semimajoraxis {
        // Ascent
        set dir to prograde.
        lock dAngle to phaseAngle-reqPhaseAngle-360*floor((phaseAngle-reqPhaseAngle)/360).
    } else {
        // Descent
        set dir to retrograde.
        lock dAngle to reqPhaseAngle-phaseAngle-360*floor((reqPhaseAngle-phaseAngle)/360).
    }

    // FIRST NODE -----------------------------------------------
    local timeToRPA is abs(dAngle/phaseAngleRate).

    local V_ is sqrt(body:mu/orbit:semimajoraxis).
    local TV is sqrt(2*body:mu*((1/(body:radius+periapsis))-(1/transferSMA/2))).
    local dV is abs(TV-V_).

    local firstNode is Node(time + timeToRPA, 0, 0, dV).
    add firstNode.

    // SECOND NODE -----------------------------------------------
    local V2 is sqrt(body:mu/orbit:semimajoraxis).
    local TV2 is sqrt(2*body:mu*((1/(body:radius+apoapsis))-(1/transferSMA/2))).
    local dV2 is abs(TV2-V2).

    local secondNode is Node(time + timeToRPA + transferTime, 0, 0, dV2).
    add secondNode.
   
    set this:message to "DeltaV " + round(dV, 2) + " m/s".
}