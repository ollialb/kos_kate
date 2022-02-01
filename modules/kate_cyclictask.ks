@lazyGlobal off.

include("kate/modules/kate_task").

// Items:
// onActivate 
// onDeactivate
// onContinue
// uiContent
global function KateCyclicTask {
    parameter class, id, cycleInSeconds. // string
    local this is KateTask(class, id).

    set this:id to id.
    set this:params to lexicon().
    set this:cycleInSeconds to cycleInSeconds.

    this:def("onContinue", KateCyclicTask_onContinue@). // returns next desired time of execution.
    //set this:onCyclic to KateCyclicTask_onContinue@:bind(this). // returns next desired time of execution.

    return this.
}

// Default implementation
local function KateCyclicTask_onContinue {
    parameter   this.

    this:optionalCall0("onCyclic").
    return time + timespan(this:cycleInSeconds).
}
