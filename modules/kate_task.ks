@lazyGlobal off.

include("kate/core/kate_object").

// Items:
// onActivate 
// onDeactivate
// onContinue
// uiContent
global function KateTask {
    parameter class, id. // string

    local this is KateObject(class, id).

    set this:id to id.
    set this:parameters to lexicon().
    set this:parameterDeclarations to lexicon().
    set this:finished to false.
    set this:uiContentHeight to 1.

    this:def("warpPoint", KateTask_warpPoint@). // returns: timestamp. 0 means none, negative means inhibit
    //set this:onActivate to KateTask_onActivate@:bind(this). 
    //set this:onDeactivate to KateTask_onDeactivate@:bind(this). 
    //set this:onContinue to KateTask_onContinue@:bind(this). // returns next desired time of execution.
    this:def("uiContent", KateTask_uiContent@). // returns: list of strings.
    this:def("declareParameter", KateTask_declareParameter@). // arg1: name of parameter, arg2: description, returns: -.
    this:def("setParameter", KateTask_setParameter@). // arg1: name of parameter, arg2: new value, returns: -.
    this:def("getParameter", KateTask_getParameter@). // arg1: name of parameter, returns: value of parameter or the default.
    this:def("getNumericalParameter", KateTask_getNumericalParameter@). // arg1: name of parameter, returns: value of parameter or the default.
    this:def("getBooleanParameter", KateTask_getBooleanParameter@). // arg1: name of parameter, returns: value of parameter or the default.
    this:def("finish", KateTask_finish@).

    return this.
}

// Default implementation
local function KateTask_warpPoint {
    parameter   this.
    return TimeStamp(0).
}

// Default implementation
local function KateTask_uiContent {
    parameter   this.

    local result is list().
    result:add(" N/A ").
    return result.
}

local function KateTask_declareParameter {
    parameter   this,
                paramId,
                defaultValue,
                paramDescription.

    local decls is this:parameterDeclarations.
    local params is this:parameters.
    set decls[paramId] to paramDescription.
    set params[paramId] to defaultValue:toString().
}

local function KateTask_getParameter {
    parameter   this,
                paramId.

    local params is this:parameters.
    if params:hasKey(paramId) {
        return params[paramId].
    } else {
        this:throw("Tried to get undeclared parameter '" + paramId + "'").
    }
}

local function KateTask_getNumericalParameter {
    parameter   this,
                paramId.

    return this:getParameter(paramId):toNumber().
}

local function KateTask_getBooleanParameter {
    parameter   this,
                paramId.

    return this:getParameter(paramId):length > 0.
}

local function KateTask_setParameter {
    parameter   this,
                paramId,
                newValue.

    local params is this:parameters.
    if params:hasKey(paramId) {
        set params[paramId] to (newValue:toString()).
    } else {
        this:throw("Tried to set undeclared parameter '" + paramId + "'").
    }
}

local function KateTask_finish {
    parameter   this.

    set this:finished to true.
}

