@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/core_modules/mission/mission_element").

global function KateMissionPlan {
    parameter name is "MPLAN".
    local this is KateObject("KateMissionPlan", name).

    set this:elements to list().

    this:def("addTask", KateMissionPlan_addTask@).

    return this.
}

local function KateMissionPlan_addTask{
    parameter   this,
                name,
                taskId,
                taskParams.
    
    local element is KateMissionElement(name, taskId, taskParams).
    this:elements:add(element).
}