@lazyGlobal off.

KATE:registerModule(KateCoreNavigationModule@).

include ("kate/modules/kate_module").
include ("kate/core_modules/navigation/exec_node_task").
include ("kate/core_modules/navigation/circularize_task").
include ("kate/core_modules/navigation/change_pe_task").
include ("kate/core_modules/navigation/change_ap_task").
include ("kate/core_modules/navigation/change_inclination_task").
include ("kate/core_modules/navigation/clear_nodes_task").
include ("kate/core_modules/navigation/intercept_task").
include ("kate/core_modules/navigation/rsvp_server_task").
include ("kate/library/kate_time_util").

local RSVP_SERVER_CORE_NAME is "rsvp-server".

global function KateCoreNavigationModule {
    local this is KateModule("KateCoreNavigationModule", "NAVIGTN").

    this:taskCreators:add("EXNOD", KateExecNodeTask@).
    this:taskCreators:add("CIRCZ", KateCircularizeTask@).
    this:taskCreators:add("CH_PE", KateChangePeTask@).
    this:taskCreators:add("CH_AP", KateChangeApTask@).
    this:taskCreators:add("CLRND", KateClearNodesTask@).
    this:taskCreators:add("CH_IN", KateChangeInclinationTask@).
    this:taskCreators:add("INTCP", KateInterceptTask@).
    this:taskCreators:add("RSVPS", KateRsvpServerTask@).


    // Overrides
    this:override("updateState", KateCoreNavigationModule_updateState@).
    this:override("renderModuleUi", KateCoreNavigationModule_renderModuleUi@).
    this:override("handleModuleInput", KateCoreNavigationModule_handleModuleInput@).

    this:def("sendRsvpRequest", KateCoreNavigationModule_sendRsvpRequest@).
    this:def("hasRsvpServerCore", KateCoreNavigationModule_hasRsvpServerCore@).
    this:def("hasRsvpInstalled", KateCoreNavigationModule_hasRsvpInstalled@).
    this:def("doRsvpRequest", KateCoreNavigationModule_doRsvpRequest@).

    // Variables
    set this:rsvpServerRole to (core:tag = RSVP_SERVER_CORE_NAME).
    set this:rsvpServerAvailable to this:hasRsvpServerCore().
    set this:rsvpDirectlyAvailable to this:hasRsvpInstalled().

    set this:offerNodeExecTask to false.
    set this:offerNodeTask to false.
    set this:offerCircularizeTask to false.
    set this:offerClearNodesTask to false.
    set this:offerRsvpClientTask to false.

    return this.
}

local function KateCoreNavigationModule_updateState {
    parameter   this.

    set this:offerNodeExecTask to hasNode and nextnode:deltav:mag > 0.1 and availableThrust > 0.
    set this:offerNodeTask to hasNode and nextnode:deltav:mag > 0.1.
    set this:offerCircularizeTask to ship:status = "SUB_ORBITAL" or ship:status = "ORBITING".
    set this:offerClearNodesTask to hasNode.
    set this:offerRsvpClientTask to not this:rsvpServerRole and hasTarget.
}

local function KateCoreNavigationModule_renderModuleUi {
    parameter   this.
    
    local result is list().

    if this:rsvpServerRole {
        result:add("<<<<<<<< Running RSVP Server >>>>>>>>>>").
        result:add("                                  ").
    } 

    if this:offerCircularizeTask and not this:offerNodeTask {
        result:add("1: Circularize " + ship:body:name + " orbit").
        result:add("2: Change " + ship:body:name + " periapsis").
        result:add("3: Change " + ship:body:name + " apoapsis").
        result:add("4: Change " + ship:body:name + " inclination").
    }

    if this:offerRsvpClientTask and hasTarget {
        result:add("                                  ").
        result:add("5: RSVP target '" + target:name + "'").
    }

    if this:offerNodeExecTask and hasNode {
        local node is nextNode.
        local nodeSpan is TimeSpan(node:eta).
        result:add("7: Exec next node in " + kate_prettyTime(nodeSpan)).
    } 

    if this:offerClearNodesTask {
        result:add("                                  ").
        result:add("0: Clear all maneuver nodes").
    } 
    
    if result:empty {
        result:add("No Navigation functions available.").
    }

    until result:length >= 10 {
        result:add("                               ").
    }

    return result.
}

local function KateCoreNavigationModule_handleModuleInput {
    parameter   this,
                runtime,
                inputCharacter.

    if this:offerCircularizeTask and not this:offerNodeTask and inputCharacter = "1" {
        this:createAndStartTask(runtime, "CIRCZ", lexicon()).
    } else if this:offerCircularizeTask and not this:offerNodeTask and inputCharacter = "2" {
        local params is lexicon().
        set params:periapsis to round(periapsis / 1000, 2):toString().
        this:createAndStartTaskWithParameterInput(runtime, "CH_PE", params).
    } else if this:offerCircularizeTask and not this:offerNodeTask and inputCharacter = "3" {
        local params is lexicon().
        set params:apoapsis to round(apoapsis / 1000, 2):toString().
        this:createAndStartTaskWithParameterInput(runtime, "CH_AP", params).
    } else if this:offerCircularizeTask and not this:offerNodeTask and inputCharacter = "4" {
        local params is lexicon().
        set params:inclination to round(ship:orbit:inclination, 2):toString().
        this:createAndStartTaskWithParameterInput(runtime, "CH_IN", params).
    } else if this:offerRsvpClientTask and hasTarget and inputCharacter = "5" {
        this:sendRsvpRequest(runtime, target).
    } else if this:offerNodeExecTask and inputCharacter = "7" {
        this:createAndStartTask(runtime, "EXNOD", lexicon()).
    } else if inputCharacter = "0" {
        this:createAndStartTask(runtime, "CLRND", lexicon()).
    }
}

local function KateCoreNavigationModule_sendRsvpRequest {
    parameter this,
              runtime,
              targetObject.

    if targetObject:istype("Body") {
        local params is lexicon().
        set params:targetBody to targetObject:name.
        this:doRsvpRequest(runtime, params).
    } else if targetObject:istype("Vessel") {
        local params is lexicon().
        set params:targetVessel to targetObject:name.
        this:doRsvpRequest(runtime, params).
    }
}

local function KateCoreNavigationModule_doRsvpRequest {
    parameter this,
              runtime,
              params.

    if this:rsvpServerAvailable {
        this:runAsyncTask(runtime, "RSVPS", params, ship:name, RSVP_SERVER_CORE_NAME, this:id).
    } else if this:rsvpDirectlyAvailable {
        this:createAndStartTaskWithParameterInput(runtime, "RSVPS", params).
    } else {
       KATE:ui:setStatus("No RSVP installation found!").
    }
}

local function KateCoreNavigationModule_hasRsvpServerCore {
    parameter   this.

    local allProcessors is list().
    list PROCESSORS in allProcessors.
    for proc in allProcessors {
        if proc:mode = "READY" and proc:tag <> core:tag and proc:tag = RSVP_SERVER_CORE_NAME {
            return true.
        }
    }
    return false.
}

local function KateCoreNavigationModule_hasRsvpInstalled {
    parameter this.

    return true. // For now a hack, requires 0:rsvp and 0:run_rsvp present.
}