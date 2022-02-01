@lazyGlobal off.

//KATE:registerModule(KateCoreVtolFlightModule@).

include ("kate/modules/kate_module").
include ("kate/core_modules/vtol/vtol_autopilot_task").
include ("kate/core_modules/flight/aero_flightplan_task").
include ("kate/library/kate_time_util").
include ("kate/library/kate_ship").

local MODE_INIT is "INITL".
local MODE_MANUAL is "PILOT".
local MODE_AUTO is "AUTOP".
local MODE_FPLAN is "FPLAN".

global function KateCoreVtolFlightModule {
    local this is KateModule("KateCoreVtolFlightModule", "VTOLFLT").

    this:taskCreators:add("VTPLT", KateVtolAutopilotTask@).
    this:taskCreators:add("FPEXE", KateAeroFlightPlanTask@).

    set this:apMode to MODE_INIT.
    set this:apCoreTask to 0.
    set this:fpTask to 0.
    set this:ownship to KateShip(ship).

    set this:apAvailable to false.
    set this:fpAvailable to false.

    // Overrides
    this:override("updateState", KateCoreVtolFlightModule_updateState@).
    this:override("renderModuleUi", KateCoreVtolFlightModule_renderModuleUi@).
    this:override("handleModuleInput", KateCoreVtolFlightModule_handleModuleInput@).
    this:override("handleMessage", KateCoreVtolFlightModule_handleMessage@).

    this:def("changeAutopilotParameter", KateCoreVtolFlightModule_changeAutopilotParameter@).
    this:def("setAutopilotParameterFromMessage", KateCoreVtolFlightModule_setAutopilotParameterFromMessage@).
    this:def("changeFlightPlanWaypoint", KateCoreVtolFlightModule_changeFlightPlanWaypoint@).

    return this.
}

local function KateCoreVtolFlightModule_updateState {
    parameter   this.

    // TODO: How to do this in a clean fashion?
    local runtime is KATE.

    // Maintain autpilot core task reference
    if this:apCoreTask <> 0 and this:apCoreTask:finished {
        set this:apCoreTask to 0.
    }
    if this:fpTask <> 0 and this:fpTask:finished {
        set this:fpTask to 0.
    }

    local hasAirbreathingEngines is this:ownship:hasAirbreathingEngines().
    set this:apAvailable to hasAirbreathingEngines and ship:status = "FLYING".
    set this:fpAvailable to this:apAvailable. // assume we can always start the autopilor core task

    if this:apMode = MODE_INIT {
        if this:apAvailable {
            set this:apMode to MODE_AUTO.
        } else {
            set this:apMode to MODE_MANUAL.
        }
    }

    local startCoreTask is this:apAvailable and this:apCoreTask = 0 and this:apMode <> MODE_MANUAL.
    local stopCoreTask is this:apCoreTask <> 0 and this:apMode = MODE_MANUAL.

    if startCoreTask {
        print "START" at (0, 34).
        local params is lexicon("altitude", ship:altitude, "speed", ship:airspeed, "heading", this:ownship:surfaceHeading()).
        set this:apCoreTask to this:createAndStartTask(runtime, "ATPLT", params).
    }
    if stopCoreTask {
        print "STOP" at (0, 35).
        this:apCoreTask:finish().
        set this:apCoreTask to 0.
    }

    local startFplanTask is this:fpAvailable and this:fpTask = 0 and this:apMode = MODE_FPLAN.
    local stopFplanTask is this:fpTask <> 0 and this:apMode <> MODE_FPLAN.
    
    if startFplanTask {
        set this:fpTask to this:createAndStartTaskWithParameterInput(runtime, "FPEXE", lexicon()).
    } 
    if stopFplanTask {
        this:fpTask:finish().
        set this:fpTask to 0.
    }
}

local function KateCoreVtolFlightModule_renderModuleUi {
    parameter   this.

    local result is list().

    local maState is choose " ██" if this:apMode = MODE_MANUAL else " ░░".
    local apState is choose " ██" if this:apMode = MODE_AUTO   else " ░░".
    local fpState is choose " ██" if this:apMode = MODE_FPLAN  else " ░░".

    local maButton is "[ 1 : " + MODE_MANUAL + maState + " ]".
    local apButton is choose "   [ 2 : " + MODE_AUTO + apState  + " ]" if this:apAvailable else "   [             ]".
    local fpButton is choose "   [ 3 : " + MODE_FPLAN + fpState + " ]" if this:fpAvailable else "   [             ]".

    result:add(maButton + apButton + fpButton).
    result:add("").
    if this:apMode = MODE_MANUAL {
        result:add("Autopilot disengaged - pilot controls active").
    } else if this:apMode = MODE_AUTO {
        result:add("[ < : HDG-5    ]   [ > : HDG+5    ]").
        result:add("[ ^ : ALT+100  ]   [ v : ALT-100  ]").
        result:add("[ CR: SPD+10   ]   [ BS: SPD-10   ]").
    } else if this:apMode = MODE_FPLAN {
        local altEnabled is choose " ██" if this:fpTask <> 0 and this:fpTask:controlAltitude else " ░░".
        local spdEnabled is choose " ██" if this:fpTask <> 0 and this:fpTask:controlSpeed else " ░░".
        local altButton is "[ 4: ALT   " + altEnabled + " ]".
        local spdButton is "[ 5: SPD   " + spdEnabled + " ]".
        if not(this:fpTask <> 0 and this:fpTask:controlAltitude) {
            result:add("[ ^ : ALT+100  ]   [ v : ALT-100  ]   " + altButton).
        } else {
            result:add("[              ]   [              ]   " + altButton).
        }
        if not(this:fpTask <> 0 and this:fpTask:controlSpeed) {
            result:add("[ CR: SPD+10   ]   [ BS: SPD-10   ]   " + spdButton).
        } else {
            result:add("[              ]   [              ]   " + spdButton).
        }
        result:add("[ 7 : PREV     ]   [ 8 : NEXT     ]").
        result:add("[ 6 : FIRST    ]   [ 9 : LAST     ]").
    }
    
    if result:empty {
        result:add("No Vtol func available: " + ship:status).
    }

    until result:length >= 10 {
        result:add("                               ").
    }

    return result.
}

local function KateCoreVtolFlightModule_handleModuleInput {
    parameter   this,
                runtime,
                inputCharacter.

    if inputCharacter = "1" {
        set this:apMode to MODE_MANUAL.
    } else if inputCharacter = "2" and this:apAvailable {
        set this:apMode to MODE_AUTO.
    } else if inputCharacter = "3" and this:fpAvailable {
        set this:apMode to MODE_FPLAN.
    }
    
    if this:apCoreTask <> 0 {
        if      inputCharacter = terminal:input:upcursorone     this:changeAutopilotParameter("altitude", 100).
        else if inputCharacter = terminal:input:downcursorone   this:changeAutopilotParameter("altitude", -100).
        else if inputCharacter = terminal:input:leftcursorone   this:changeAutopilotParameter("heading", -5, 360).
        else if inputCharacter = terminal:input:rightcursorone  this:changeAutopilotParameter("heading", 5, 360).
        else if inputCharacter = terminal:input:enter           this:changeAutopilotParameter("speed", 10).
        else if inputCharacter = terminal:input:backspace       this:changeAutopilotParameter("speed", -10).
    }

    if this:apMode = MODE_FPLAN and this:fpTask <> 0 {
        if      inputCharacter = "7"                            this:changeFlightPlanWaypoint("increment", -1).
        else if inputCharacter = "8"                            this:changeFlightPlanWaypoint("increment", +1).
        else if inputCharacter = "6"                            this:changeFlightPlanWaypoint("first", 0).
        else if inputCharacter = "9"                            this:changeFlightPlanWaypoint("last", 0).
        else if inputCharacter = "4"                            set this:fpTask:controlAltitude to not this:fpTask:controlAltitude.
        else if inputCharacter = "5"                            set this:fpTask:controlSpeed    to not this:fpTask:controlSpeed.
    }
}

local function KateCoreVtolFlightModule_handleMessage {
    parameter   this,
                runtime,
                message.
                
    if message:haskey("content") {
        local msg is message:content.
        local params is getOrDefault(msg, "autopilotParameters", 0).
        if this:apCoreTask <> 0 and params <> 0 {
            this:setAutopilotParameterFromMessage(params, "altitude").
            this:setAutopilotParameterFromMessage(params, "heading").
            this:setAutopilotParameterFromMessage(params, "speed").
        }
         message:acknowledge().
    } else {
        this:super:handleMessage(runtime, message).
    }
}

local function KateCoreVtolFlightModule_changeAutopilotParameter {
    parameter this,
              name,
              delta,
              modulo is 0.

    local precision is abs(delta).
    local oldValue is this:apCoreTask:getNumericalParameter(name).
    local newValue is choose mod(round((oldValue + delta) / precision) * precision, modulo) if modulo <> 0 
                        else     round((oldValue + delta) / precision) * precision.
    if name = "heading" and newValue < 0 set newValue to 360 - newValue.
    this:apCoreTask:setParameter(name, newValue).
}

local function KateCoreVtolFlightModule_setAutopilotParameterFromMessage {
    parameter this,
              message,
              name.
    if message:hasKey(name) {
        this:apCoreTask:setParameter(name, message[name]).
    }
}

local function KateCoreVtolFlightModule_changeFlightPlanWaypoint {
    parameter this,
              mode,
              value.

    if mode = "increment" {
        this:fpTask:requestWaypointIndex(this:fpTask:currentWaypointIndex + value).
    } else if mode = "first" {
        this:fpTask:requestWaypointIndex(0).
    } else if mode = "last" {
        this:fpTask:requestWaypointIndex(this:fpTask:flightPlanLength - 1).
    }
}