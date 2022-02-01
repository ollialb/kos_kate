@lazyGlobal off.

//KATE:registerModule(MissionControlSystemModule@).

include("kate/modules/kate_module").
include("kate/core_modules/mission/mission_plan").
include("kate/ui/kate_input_field").

global function MissionControlSystemModule {
    local this is KateModule("MissionControlSystemModule", "CTRLMSN").

    set this:currentPlan to KateMissionPlan("DEFAULT").
    
    this:override("updateState", MissionControlSystemModule_updateState@).
    this:override("renderModuleUi", MissionControlSystemModule_renderModuleUi@).
    this:override("handleModuleInput", MissionControlSystemModule_handleModuleInput@).

    return this.
}

local function MissionControlSystemModule_updateState {
    parameter   this.

    // Nothing
}

local function MissionControlSystemModule_renderModuleUi {
    parameter   this.
    
    local result is list().
    return result.
}

local function MissionControlSystemModule_handleModuleInput {
    parameter   this,
                runtime,
                inputCharacter.
}
