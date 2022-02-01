@lazyGlobal off.

include ("kate/core/kate_object").

global function KateAeroFlightPlan {
    parameter name.
    local this is KateObject("KateAeroFlightPlan", name).

    this:def("numberOfWaypoints", KateAeroFlightPlan_numberOfWaypoints@).
    this:def("getWaypoint", KateAeroFlightPlan_getWaypoint@).

    set this:waypoints to lexicon().
    set this:plan to lexicon().

    set this:errors to "".

    local planPath is "/kate/data/flightplans/" + name + ".json".
    local waypointsPath is "/kate/data/waypoints.json".

    copypath("archive:/kate/data", "kate").
    if exists(planPath) and exists(waypointsPath) {
        local waypoints is readJson(waypointsPath).
        for wpName in waypoints:keys {
            local wp is waypoints[wpName].
            if wp:hasKey("latitude") and wp:hasKey("longitude") and wp:hasKey("elevation") {
                this:waypoints:add(wpName, wp).
            } else {
                set this:errors to this:errors + "BadWp(" + wpName + ") ".
            }
        }
        local plan is readJson(planPath).
        if plan:hasKey("waypoints") and plan:waypoints:istype("List") {
            set this:plan:waypoints to list().
            for planWp in plan:waypoints {
                if planWp:hasKey("name") and planWp:hasKey("altitude") and planWp:hasKey("speed") and this:waypoints:hasKey(planWp:name) {       
                    set planWp:waypoint to this:waypoints[planWp:name].
                    this:plan:waypoints:add(planWp).
                } else {
                    set this:errors to this:errors + "BadPlanWp(" + planWp + ") ".
                }
            }
        } else {
             set this:errors to this:errors + "MissingWpInFlightPlan(" + name + ") ".
        }
    } else {
        if not exists(planPath) set this:errors to this:errors + "PlanNotFound(" + planPath + ")".
        if not exists(waypointsPath) set this:errors to this:errors + "WpsNotFound(" + waypointsPath + ")".
    }

    return this.
}

local function KateAeroFlightPlan_numberOfWaypoints {
    parameter this.
    if this:errors:length = 0 {
        return this:plan:waypoints:length.
    } else {
        return 0.
    }
}

local function KateAeroFlightPlan_getWaypoint {
    parameter this,
              index.
    if this:errors:length = 0 and index < this:plan:waypoints:length {
        return this:plan:waypoints[index].
    } else {
        return 0.
    }
}