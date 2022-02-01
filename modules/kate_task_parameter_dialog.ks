@lazyGlobal off.

include("kate/core/kate_object").
include("kate/ui/kate_input_field").

// drawUi (offX, offY)
global function KateTaskParameterDialog {
    parameter   module,
                task.
    local this is KateObject("KateTaskParameterDialog", "DIAG").

    set this:module to module.
    set this:task to task.
    set this:inputFields to list().
    set this:currentField to 0.

    this:def("init", KateTaskParameterDialog_init@).
    this:def("uiContent", KateTaskParameterDialog_uiContent@).
    this:def("handleUiInput", KateTaskParameterDialog_handleUiInput@).

    this:init().

    return this.
}

local function KateTaskParameterDialog_init {
    parameter this.
    
    local paramDecls is this:task:parameterDeclarations.
    for paramId in paramDecls:keys {
        local description is paramDecls[paramId].
        local currentValue is this:task:safeCall1("getParameter", paramId).
        local inputField is KateInputField(paramId, description:padright(20), 10, 0, currentValue, true).
        this:inputFields:add(inputField).
    }
}

local function KateTaskParameterDialog_uiContent {
    parameter this.

    local result is list().

    local canExit is choose "' (up to exit)" if this:currentField = 0 else "".

    result:add("Parameters for Task '" + this:task:id + canExit).
    result:add("---------------------------------------------------------------------------------").
   
    local index is 0.
    for inputField in this:inputFields {
        inputField:safeCall1("setActive", index = this:currentField).
        result:add(inputField:safeCall0("uiContent")).
        set index to index + 1.
    }

    return result.
}

local function KateTaskParameterDialog_handleUiInput {
    parameter this,
              runtime,
              inputCharacter.

    local fieldCount is this:inputFields:length.

    if inputCharacter = terminal:input:enter {
        for inputField in this:inputFields {
            this:task:safeCall2("setParameter", inputField:id, inputField:workingstr).
        }
        this:module:safeCall2("finishTaskParameterDialog", runtime, this:task).
    } else if inputCharacter = terminal:input:downcursorone {
        set this:currentField to this:currentField + 1.
        if this:currentField >= fieldCount set this:currentField to 0.
    } else if inputCharacter = terminal:input:upcursorone {
        set this:currentField to this:currentField - 1.
        //if this:currentField < 0 set this:currentField to (fieldCount - 1).
        if this:currentField < 0 {
            this:module:safeCall2("abortTaskParameterDialog", runtime, this:task).
        }
    } else {
        local activeField is this:inputFields[this:currentField].
        activeField:safeCall1("handleUiInput", inputCharacter).
    }
}