@lazyGlobal off.

KATE:registerModule(KateCoreAutopilotModule@).

include ("kate/modules/kate_module").
include ("kate/core_modules/autopilot/atm_ascent_task").
include ("kate/core_modules/autopilot/vac_ascent_task").
include ("kate/core_modules/autopilot/docking_task").
include ("kate/core_modules/autopilot/point_land_task").
include ("kate/modules/kate_task_menu").
include ("kate/library/kate_time_util").
include ("kate/library/kate_ship").
include ("kate/library/kate_impact_predictor").

global function KateCoreAutopilotModule {
    local this is KateModule("KateCoreAutopilotModule", "AUTOPLT").

    this:taskCreators:add("A_ASC", KateAtmosphericAscentTask@).
    this:taskCreators:add("V_ASC", KateVacuumAscentTask@).
    this:taskCreators:add("DOCKG", KateDockingTask@).
    this:taskCreators:add("PTLND", KatePointLandTask@).
    this:taskCreators:add("AERBK", KateAerobrakeTask@).

    // Menu
    set this:menu to KateTaskMenu().
    //this:menu:addItem("X", "Test", {parameter runtime. print "Hallo".}, true).

    // Overrides
    this:override("updateState", KateCoreAutopilotModule_updateState@).
    this:override("renderModuleUi", KateCoreAutopilotModule_renderModuleUi@).
    this:override("handleModuleInput", KateCoreAutopilotModule_handleModuleInput@).

    set this:impactPredictor to KateImpactPredictor().
    set this:ownship to KateShip().

    set this:offerAtmLaunchTask to false.
    set this:offerVacLaunchTask to false.
    set this:offerPointLandTaskFromOrbit to false.
    set this:offerPointLandTaskFromLanding to false.
    set this:offerDockingTask to false.
    set this:offerAerobrake to false.

    return this.
}

local function KateCoreAutopilotModule_updateState {
    parameter   this.

    set this:offerAtmLaunchTask to body:atm:exists and (ship:status = "PRELAUNCH" or ship:status = "LANDED").
    set this:offerVacLaunchTask to not body:atm:exists and (ship:status = "PRELAUNCH" or ship:status = "LANDED").
    set this:offerPointLandTaskFromOrbit to ship:status = "ORBITING" and ship:orbit:eccentricity < 0.1 and availableThrust > 0.
    set this:offerPointLandTaskFromLanding to this:impactPredictor:hasImpact().
    set this:offerDockingTask to ship:status = "ORBITING" and hasTarget and (target:isType("Vessel") or target:isType("DockingPort")).
    set this:offerAerobrake to ship:body:atm:exists and (ship:status = "ORBITING" or ship:status = "SUB_ORBITAL") and availableThrust > 0.
}

local function KateCoreAutopilotModule_renderModuleUi {
    parameter   this.
    
    local result is list().

    if this:offerAtmLaunchTask {
        result:add("1: Atm. ascent on " + ship:body:name).
    }
    if this:offerVacLaunchTask {
        result:add("1: Vac. ascent on " + ship:body:name).
    }
    if this:offerPointLandTaskFromOrbit {
        if hasTarget and target:istype("Vessel") {
            result:add("3: Point landing at '" + target:name + "'").
        } else {
            result:add("3: Point landing from orbit").
        }
    } 
    if this:offerPointLandTaskFromLanding {
         if hasTarget and target:istype("Vessel") {
            result:add("4: Point landing at '" + target:name + "'").
        } else if this:impactPredictor:hasImpact() {
            result:add("4: Point landing to current impact").
        } else {
            result:add("4: Point landing to current position").
        }
    } 
    if this:offerAerobrake {
        result:add("5: Aerobrake at " + ship:body:name + "").
    }
    if this:offerDockingTask {
        if target:isType("Vessel") {
            result:add("6: Dock at '" + target:name + "'").
        } else if target:isType("Part") {
            result:add("6: Dock '" + target:ship:name + "@" + target:name + "'").
        }
    } 
    
    if result:empty {
        result:add("No AP func available: " + ship:status).
    }

    return result.
}

local function KateCoreAutopilotModule_handleModuleInput {
    parameter   this,
                runtime,
                inputCharacter.

    if this:offerAtmLaunchTask and inputCharacter = "1" {
        //local launchTWR is this:ownship:possibleThrust() / ship:mass.
        //local turnExponent is max(1 / (2.25*launchTWR - 1.35), 0.25).
        local turnExponent is 2.
        this:createAndStartTaskWithParameterInput(runtime, "A_ASC", lexicon("apoapsis", "150", "inclination", "90", "curvature", turnExponent:toString)).
    } else  if this:offerVacLaunchTask and inputCharacter = "1" {
        this:createAndStartTaskWithParameterInput(runtime, "V_ASC", lexicon()).
    } else  if this:offerPointLandTaskFromOrbit and inputCharacter = "3" {
        local proposedCoordinates is lexicon().
        if hasTarget and target:istype("Vessel") {
            set proposedCoordinates:latitude to target:latitude.
            set proposedCoordinates:longitude to target:longitude.
        }
        this:createAndStartTaskWithParameterInput(runtime, "PTLND", proposedCoordinates).
    } else if this:offerPointLandTaskFromLanding and inputCharacter = "4" {
        if hasTarget and target:istype("Vessel") {
            this:createAndStartTask(runtime, "PTLND", lexicon("latitude", target:latitude:toString, "longitude", target:longitude:toString)).
        } else if this:impactPredictor:hasImpact() {
            this:createAndStartTask(runtime, "PTLND", lexicon("latitude", ship:geoposition:lat:toString, "longitude", ship:geoposition:lng:toString)).
        } else {
            local impactPosition is this:impactPredictor:averagedEstimatedImpactPosition():position.
            local impactGeoposition is body:geopositionof(impactPosition).
            this:createAndStartTask(runtime, "PTLND", lexicon("latitude", impactGeoposition:lat:toString, "longitude", impactGeoposition:lng:toString)).
        }
    } else if this:offerAerobrake and inputCharacter = "5" {
       this:createAndStartTaskWithParameterInput(runtime, "AERBK", lexicon()).
    } else if this:offerDockingTask and inputCharacter = "6" {
        this:createAndStartTask(runtime, "DOCKG", lexicon()).
    }
}