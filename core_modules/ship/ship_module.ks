@lazyGlobal off.

KATE:registerModule(KateCoreShipModule@).

include ("kate/core_modules/ship/ship_control_task").
include ("kate/modules/kate_module").
include ("kate/library/kate_ship").

global function KateCoreShipModule {
    local this is KateModule("KateCoreShipModule", "SHIPSYS").

    this:taskCreators:add("SCTRL", KateShipControlTask@).

    // Overrides
    this:override("updateState", KateCoreShipModule_updateState@).
    this:override("renderModuleUi", KateCoreShipModule_renderModuleUi@).
    this:override("handleModuleInput", KateCoreShipModule_handleModuleInput@).

    set this:ownship to KateShip(ship).

    return this.
}

local function KateCoreShipModule_updateState {
    parameter   this.
    // Nothing
}

local function KateCoreShipModule_renderModuleUi {
    parameter   this.
    
    local result is list().
    local otherCpus is this:ownship:otherLocalProcessorsActive().

    result:add("KSS '" + ship:name + "'").
    result:add("─────────────────────────────────────────").
    result:add("1: Panels    [" + (choose "X" if panels else " ")    + "]       6: Lights [" + (choose "X" if lights else " ") + "]").
    result:add("2: Radiators [" + (choose "X" if radiators else " ") + "]       7: Brakes [" + (choose "X" if brakes else " ") + "]").
    result:add("3: Ladders   [" + (choose "X" if ladders else " ")   + "]       8: Bays   [" + (choose "X" if bays else " ") + "]").
    result:add("4: Drills    [" + (choose "X" if drills else " ")    + "]       9: Legs   [" + (choose "X" if legs else " ") + "]").
    result:add("5: ISRUs     [" + (choose "X" if isru else " ")      + "]       0: Gears  [" + (choose "X" if gear else " ") + "]").
    result:add("-: Other CPU [" + (choose "X" if otherCpus else " ") + "]").

    return result.
}

local function KateCoreShipModule_handleModuleInput {
    parameter   this,
                runtime,
                inputCharacter.

    local toggleAG is "".

    if inputCharacter = "1" { set toggleAG to "panels". }
    if inputCharacter = "2" { set toggleAG to "radiators". }
    if inputCharacter = "3" { set toggleAG to "ladders". }
    if inputCharacter = "4" { set toggleAG to "drills". }
    if inputCharacter = "5" { set toggleAG to "isru". }
    if inputCharacter = "6" { set toggleAG to "lights". }
    if inputCharacter = "7" { set toggleAG to "brakes". }
    if inputCharacter = "8" { set toggleAG to "bays". }
    if inputCharacter = "9" { set toggleAG to "legs". }
    if inputCharacter = "0" { set toggleAG to "gear". }
    if inputCharacter = "-" { set toggleAG to "otherCpus". }

    if toggleAG <> "" {
        local params is lexicon().
        set params["toggleAG"] to toggleAG.
        this:createAndStartTask(runtime, "SCTRL", params).
    }
}