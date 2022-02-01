@lazyGlobal off.

include ("kate/modules/kate_cyclictask").
include ("kate/library/kate_ship").
include ("kate/library/kate_time_util").
include ("kate/library/kate_dist_util").
include ("kate/library/kate_averaged_value").
include ("kate/library/kate_geodetic").
include ("kate/core_modules/flight/aero_flightplan").

local MIN_WP_DISTANCE is 1000. // 1 km distance required for next WP
local AP_COMMAND_INTERVAL is 1. // 1s between autopilot command intervals

global function KateAeroFlightPlanTask{
    local this is KateCyclicTask("KateAeroFlightPlanTask", "FPEXE", 0.1).

    this:declareParameter("flightplan", "bases", "name: ").

    this:override("uiContent", KateAeroFlightPlan_uiContent@).
    
    this:def("onActivate", KateAeroFlightPlan_onActivate@).
    this:def("onDeactivate", KateAeroFlightPlan_onDeactivate@).
    this:def("onCyclic", KateAeroFlightPlan_onCyclic@).
    this:def("setAutopilotParameters", KateAeroFlightPlan_setAutopilotParameters@).
    this:def("checkWaypointCompletion", KateAeroFlightPlan_checkWaypointCompletion@).
    this:def("requestWaypointIndex", KateAeroFlightPlan_requestWaypointIndex@).
    this:def("updateWaypoint", KateAeroFlightPlan_updateWaypoint@).
    this:def("calculateWaypoint", KateAeroFlightPlan_calculateWaypoint@).

    set this:message to "".
    set this:uiContentHeight to 3.
    set this:currentWaypointIndex to -1.

    set this:ownship to KateShip(ship).
    set this:flightplanName to "".
    set this:flightplan to 0.
    set this:controlAltitude to true.
    set this:controlSpeed to true.

    set this:flightPlanLength to 0.
    set this:wpName to "".
    set this:wpGeoposition to 0.
    set this:wpDistance to 0.
    set this:wpHeading to 0.
    set this:wpAltitude to 0.
    set this:wpSpeed to 0.
    set this:timeToNextLeg to 0.
    set this:distanceToNextLeg to 0.
    set this:requestedWaypointIndex to 0.
    set this:nextWpName to "N/A".

    set this:lastApCommandTime to time.

    return this.
}

local function KateAeroFlightPlan_onActivate {
    parameter this.

    set this:flightplanName to this:getParameter("flightplan").
    set this:flightPlan to KateAeroFlightPlan(this:flightplanName).
    set this:currentWaypointIndex to -1.
    set this:requestedWaypointIndex to 0.
    set this:flightPlanLength to this:flightPlan:numberOfWaypoints().
}

local function KateAeroFlightPlan_onDeactivate {
    parameter this.

    set this:flightPlan to 0.
}

local function KateAeroFlightPlan_uiContent {
    parameter this.
    
    local result is list().
    if this:flightPlan = 0 {
        result:add("No flight plan loaded").
    } else if this:flightPlan:errors:length > 0 {
        result:add("Errors: " + this:flightPlan:errors).
    } else if this:currentWaypointIndex >= 0 and this:currentWaypointIndex < this:flightPlanLength {
        local currentWp is this:flightPlan:getWaypoint(this:currentWaypointIndex).
        local currentWpName is choose currentWp:name if currentWp <> 0 else "N/A".

        local fpBlock is   ("FPLAN [" + this:flightplanName + ":" + (this:currentWaypointIndex+1) + "/" + this:flightPlanLength + "]"):padright(20).
        local cwBlock is   ("CUR [" + currentWpName + "]"):padright(20).
        local nwBlock is   ("NXT [" + this:nextWpName + "]"):padright(20).
        local hdgBlock is  ("HDG " + (round(kate_compassHeading(this:wpHeading)) + "°")):padright(7) + (" ~" + kate_prettyDistance(this:wpDistance,1)):padright(12).
        local asBlock is   ("ALT " + kate_prettyDistance(this:wpAltitude,0) + "  SPD " + kate_prettySpeed(this:wpSpeed,0)):padright(20).
        local distBlock is ("DTN " + kate_prettyDistance(this:distanceToNextLeg)):padright(20).
        local etaBlock is  ("ETA " + kate_prettyTime(TimeSpan(this:timeToNextLeg))):padright(20).

        result:add(fpBlock   + cwBlock  + nwBlock).
        result:add(hdgBlock  + asBlock  + "LAT " + kate_prettyLatitude(this:wpGeoposition):padleft(10)).
        result:add(distBlock + etaBlock + "LNG " + kate_prettyLongitude(this:wpGeoposition):padleft(10)).
    } else {
        result:add("FPLAN [" + this:flightplanName + ":" + (this:currentWaypointIndex+1) + "/" + this:flightPlanLength + "] - Out Of Bounds").
    }
  
    return result. 
}

local function KateAeroFlightPlan_onCyclic {
    parameter this.

    if this:flightPlan = 0 or this:flightPlan:errors:length > 0 {
        this:finish().
    } else {
        // Advance Wp as requested
        this:updateWaypoint().
    }
}

local function KateAeroFlightPlan_updateWaypoint {
    parameter this.

    // Advance Wp if requested
    if this:requestedWaypointIndex <> -1 {
        if this:requestedWaypointIndex >= 0 and this:requestedWaypointIndex < this:flightPlanLength {
            set this:currentWaypointIndex to this:requestedWaypointIndex.
            set this:requestedWaypointIndex to -1.
        } else {
            set this:message to "Illegal WP request: " + this:requestedWaypointIndex.
            set this:requestedWaypointIndex to -1.
        }
    }

    local currentWp is this:flightPlan:getWaypoint(this:currentWaypointIndex).
    if currentWP <> 0 {
        this:setAutopilotParameters(currentWp).
        this:checkWaypointCompletion().
    }
}

local function KateAeroFlightPlan_calculateWaypoint {
    parameter this.

    // Update waypoint parameters
    local currentWp is this:flightPlan:getWaypoint(this:currentWaypointIndex).
    if currentWP <> 0 {
        set this:wpGeoposition to latlng(currentWp:waypoint:latitude, currentWp:waypoint:longitude).
        set this:wpHeading to this:wpGeoposition:heading.
        set this:wpDistance to this:wpGeoposition:distance.
        set this:wpAltitude to currentWp:altitude.
        set this:wpSpeed to currentWp:speed.
    }
}

local function KateAeroFlightPlan_setAutopilotParameters {
    parameter this, waypoint.

    this:calculateWaypoint().

    if time > this:lastApCommandTime + AP_COMMAND_INTERVAL {
        local params is lexicon("heading", this:wpHeading).
        if this:controlAltitude params:add("altitude", this:wpAltitude).
        if this:controlSpeed params:add("speed", this:wpSpeed).
        local autopilotParameters is lexicon("autopilotParameters", params).
        KATE:sendMessage("FLTAERO", ship:name, core:tag, "FLTAERO", autopilotParameters).
        set this:lastApCommandTime to time.
    }
}

local function KateAeroFlightPlan_checkWaypointCompletion {
    parameter this.

    local flightPlanLength is this:flightPlan:numberOfWaypoints().
    local currentWp is this:flightPlan:getWaypoint(this:currentWaypointIndex).
    local nextWp is 0.
    if this:currentWaypointIndex < flightPlanLength - 1 {
        set nextWp to this:flightPlan:getWaypoint(this:currentWaypointIndex + 1).
    }

    if nextWP = 0 {
        // We are already at the last wp
        set this:timeToNextLeg to this:wpDistance / ship:groundspeed.
        set this:distanceToNextLeg to this:wpDistance.
        set this:nextWpName to "N/A".
    } else {
        // We need to start turning soon enough
        local currentWpGeoposition is latlng(currentWp:waypoint:latitude, currentWp:waypoint:longitude).
        local nextWpGeoposition is latlng(nextWp:waypoint:latitude, nextWp:waypoint:longitude).

        local currentWpToNextWpAngle is kate_greatCircleAzimuth(currentWpGeoposition, nextWpGeoposition).
        local currentHeading is this:ownship:surfaceHeading().
        local headingChange is currentHeading - currentWpToNextWpAngle.

        local estimatedMaxTurnRate is 1. // degrees per second
        local timeToTurn is abs(headingChange) / estimatedMaxTurnRate.
        local distanceForTurnStart is max(MIN_WP_DISTANCE, 0.5 * timeToTurn * ship:groundspeed).

        set this:distanceToNextLeg to this:wpDistance - distanceForTurnStart.
        set this:timeToNextLeg to this:distanceToNextLeg / ship:groundspeed.
        set this:nextWpName to nextWp:name.

        if this:distanceToNextLeg < 0 {
            set this:requestedWaypointIndex to this:currentWaypointIndex + 1.
        }
    }
}

local function KateAeroFlightPlan_requestWaypointIndex {
    parameter this, index.
    set this:requestedWaypointIndex to index.
}