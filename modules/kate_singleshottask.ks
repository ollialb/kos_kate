@lazyGlobal off.

include("kate/modules/kate_task").

// Items:
// onActivate 
// onDeactivate
// onContinue
// uiContent
global function KateSingleShotTask {
    parameter class, id.
    local this is KateTask(class, id).

    set this:id to id.
    set this:params to lexicon().

    this:abstract("performOnce").
    
    this:def("onContinue", KateSingleShotTask_onContinue@). // returns next desired time of execution.

    return this.
}

// Default implementation
local function KateSingleShotTask_onContinue {
    parameter   this.

    this:optionalCall0("performOnce").
    this:finish().
    return time + TimeSpan(1).
}