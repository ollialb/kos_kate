@lazyGlobal off.

include ("kate/modules/kate_singleshottask").
include ("kate/library/kate_ship").

global function KateShipControlTask {
    local this is KateSingleShotTask("KateShipControlTask", "SCTRL").

    this:declareParameter("toggleAG", "", "Name of action group to be toggled.").

    this:override("uiContent", KateShipControlTask_uiContent@).
    this:override("performOnce", KateShipControlTask_performOnce@).

    set this:message to "".
    set this:uiContentHeight to 1. 
    set this:ownship to KateShip(ship).

    return this.
}

local function KateShipControlTask_uiContent {
    parameter   this.
    local result is list().

    result:add(this:message).

    return result.
}

local function KateShipControlTask_performOnce {
    parameter   this.

    local toggleAG is this:getParameter("toggleAG").

    if toggleAG = "panels" { toggle panels. }
    if toggleAG = "radiators" { toggle radiators. }
    if toggleAG = "ladders" { toggle ladders. }
    if toggleAG = "drills" { toggle drills. }
    if toggleAG = "isru" { toggle isru. }
    if toggleAG = "lights" { toggle lights. }
    if toggleAG = "brakes" { toggle brakes. }
    if toggleAG = "legs" { toggle legs. }
    if toggleAG = "gear" { toggle gear. }
    if toggleAG = "otherCpus" { this:ownship:activateOtherLocalProcessors(not this:ownship:otherLocalProcessorsActive()). }

    set this:message to "Toggled " + toggleAG.
}