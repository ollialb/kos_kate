@lazyGlobal off.

global function getOrDefault {
    parameter object,
              name,
              defaultValue.
    return choose object[name] if object:hasKey(name) else defaultValue.
}

global function getOrCalculate {
    parameter object,
              name,
              defaultValueCalcDelegate.
    return choose object[name] if object:hasKey(name) else defaultValueCalcDelegate().
}

global function KateObject {
    parameter objClass,
              objId.

    local this is lexicon().

    set this:class to objClass.
    set this:id to objId.

    set this:throw to KateObject_throw@:bind(this).
    set this:super to lexicon().

    set this:def to KateObject_def@:bind(this).
    set this:override to KateObject_override@:bind(this).
    set this:abstract to KateObject_abstract@:bind(this).

    this:def("isClass", KateObject_isClass@). 
    this:def("getOrDefault", KateObject_getOrDefault@). 

    this:def("optionalCall0", KateObject_optionalCall0@). 
    this:def("optionalCall1", KateObject_optionalCall1@).
    this:def("optionalCall2", KateObject_optionalCall2@). 

    this:def("safeCall0", KateObject_safeCall0@).
    this:def("safeCall1", KateObject_safeCall1@).
    this:def("safeCall2", KateObject_safeCall2@).

    this:def("onMessage", KateObject_onMessage@).

    return this.
}

local function KateObject_isClass {
    parameter   this,
                className.

    return this:class = className.
}

local function KateObject_def {
    parameter   this,
                methodName,
                funcDef.

    local delegate is funcDef:bind(this). 
    if this:haskey(methodName) {
        this:throw("Use override, when redefining object methods").
    } else {
        set this[methodName] to delegate.
    }
}

local function KateObject_override {
    parameter   this,
                methodName,
                funcDef.

    local delegate is funcDef:bind(this).
    local super is this:super.
    if not this:haskey(methodName) {
        this:throw("Use def, when not redefining object methods").
    } else {
        local superDelegate is this[methodName].
        set super[methodName] to superDelegate.
        set this[methodName] to delegate.
    }
}

local function KateObject_abstract {
    parameter   this,
                methodName.

    local delegate is KateObject_abstractMethodHandler@:bind(this, methodName). 
    if this:haskey(methodName) {
        this:throw("Cannot declare 'abstract' for existing methods, use override.").
    } else {
        set this[methodName] to delegate.
    }
}

local function KateObject_abstractMethodHandler {
    parameter   this,
                methodName.
     this:throw("Method '" + methodName + "' was declared abstract, and must be overridden.").
}

local function KateObject_getOrDefault {
    parameter   this,
                attrName,
                defaultValue.

    if this:haskey(attrName) {
        return this[attrName].
    } else {
        return defaultValue.
    }
}


local function KateObject_optionalCall0 {
    parameter   this,
                methodName.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call().
        } else {
            return "UNDEFINED".
        }
    } 
}

local function KateObject_optionalCall1 {
    parameter   this,
                methodName,
                p1.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call(p1).
        } else {
            return "UNDEFINED".
        }
    }
}

local function KateObject_optionalCall2 {
    parameter   this,
                methodName,
                p1, p2.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call(p1, p2).
        } else {
            return "UNDEFINED".
        }
    }
}

local function KateObject_safeCall0 {
    parameter   this,
                methodName.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call().
        } else {
            this:throw("Tried to call dead method " + methodName).
        }
    } else {
        this:throw("Tried to call undefined method " + methodName).
    }
}

local function KateObject_safeCall1 {
    parameter   this,
                methodName,
                p1.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call(p1).
        } else {
            this:throw("Tried to call dead method " + methodName).
        }
    } else {
        this:throw("Tried to call undefined method " + methodName).
    }
}

local function KateObject_safeCall2 {
    parameter   this,
                methodName,
                p1, p2.

    if this:haskey(methodName) {
        local delegate is this[methodName].
        if not delegate:isdead {
            return delegate:call(p1, p2).
        } else {
            this:throw("Tried to call dead method " + methodName).
        }
    } else {
        this:throw("Tried to call undefined method " + methodName).
    }
}

local function KateObject_throw {
    parameter   this,
                message.

    clearScreen.
    print "----------------------------------------------------------".
    print "EXCEPTION at " + this:class + ":" + this:id + ": ".
    print message.
    print "----------------------------------------------------------".
    // Dirty: force exception, since there is no EXIT command.
    print 1/0.
}

local function KateObject_onMessage {
    parameter   this,
                message.

    local reason is "Unknown reason".
    if message:istype("Lexicon") {
        if message:hasKey("method") { // string
            local methodName is message["method"].
            local params is choose message["params"] if message:hasKey("params") else list().
            local optional is choose message["optional"] if message:hasKey("optional") else false.
            local paramsCount is params:length.
            if optional {
                if paramsCount = 0 {
                    this:optionalCall0(methodName).
                } else if paramsCount = 1 {
                    this:optionalCall1(methodName, params[0]).
                } else if paramsCount = 1 {
                    this:optionalCall2(methodName, params[0], params[1]).
                }
            } else {
                if paramsCount = 0 {
                    this:safeCall0(methodName).
                } else if paramsCount = 1 {
                    this:safeCall1(methodName, params[0]).
                } else if paramsCount = 1 {
                    this:safeCall2(methodName, params[0], params[1]).
                }
            }
        } else {
            set reason to "No method specified.". 
        }
    } 
    this:throw("Cannot handle message: " + reason).
}