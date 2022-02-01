@lazyGlobal off.

include ("kate/modules/kate_singleshottask").

// Creates two maneuver nodes for a Hohmann transfer intercept to a target in another orbit around the same body.
global function KateRsvpServerTask {
    local this is KateSingleShotTask("KateRsvpServerTask", "RSVPS").

    this:declareParameter("targetBody", "", "Target body name: ").
    this:declareParameter("targetVessel", "", "Target vessel name: ").
    this:declareParameter("searchDuration", "1", "Search duration [d]: ").
    this:declareParameter("targetPeriapsis", "150", "Target Periapsis [km]: ").

    this:override("uiContent", KateRsvpServerTask_uiContent@).
    this:override("performOnce", KateRsvpServerTask_performOnce@).

    this:def("handleRequest", KateRsvpServerTask_handleRequest@).

    set this:message to "".
    set this:uiContentHeight to 1. 

    return this.
}

local function KateRsvpServerTask_uiContent {
    parameter   this.
    local result is list().

    result:add("Processing request: " + this:message).

    return result.
}

local function KateRsvpServerTask_performOnce {
    parameter   this.

    local bodyName is this:getParameter("targetBody").
    local vesselName is this:getParameter("targetVessel").

    if (bodyName <> "") {
        if bodyExists(bodyName) {
            local targetBody is body(bodyName).
            set this:message to "rsvp body '" + targetBody:name + "'".
            this:handleRequest(targetBody).
        } else {
            set this:message to "unknown body '" + bodyName + "'".
        }
    } else if (vesselName <> "") {
        local possibleTargets is list().
        local targetVessel is 0.
        list targets in possibleTargets.
        for candidate in possibleTargets {
            if candidate:name = vesselName {
                set targetVessel to candidate.
            }
        }
        if targetVessel <> 0 {
            set this:message to "rsvp vessel '" + targetVessel:name + "'".
            this:handleRequest(targetVessel).
        } else {
             set this:message to "unknown vessel '" + vesselName + "'".
        }
    } else {
        set this:message to "neither body nor vessel given".
    }

    KATE:ui:refresh().
}

local function KateRsvpServerTask_handleRequest {
    parameter   this,
                targetObject.

    local searchDurationStr is this:getParameter("searchDuration").
    local searchDuration is searchDurationStr:toScalar(1) * 86400.
    local targetPeriapsisStr is this:getParameter("targetPeriapsis").
    local targetPeriapsis is targetPeriapsisStr:toScalar(150) * 1000.

    local oldIpu is config:ipu.
    set config:ipu to 2000.
    runoncepath("0:/rsvp/main").
    if targetObject:istype("Vessel") {
        local options is lexicon("create_maneuver_nodes", "both", "verbose", true, "search_duration", searchDuration).
        rsvp:goto(targetObject, options).
    } else {
        local options is lexicon("create_maneuver_nodes", "both", "verbose", true, "search_duration", searchDuration, "final_orbit_periapsis", targetPeriapsis).
        rsvp:goto(targetObject, options).
    }
    set config:ipu to oldIpu.
}