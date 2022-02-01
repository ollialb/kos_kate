@lazyGlobal off.

include("kate/core/kate_object").

// drawUi (offX, offY)
global function KateTaskMenuItem {
    parameter pKey,                         // Single character string
              pMessage,                     // String or delegate returning a string
              pSelectionAction,             // Delegate which is called, when the given key was selected and the action was available (p0: runtime).
              pActiveCondition is true.     // Boolean or delegate returning a boolean

    local this is KateObject("KateTaskMenuItem", "Key_" + pKey).

    set this:screenKey to pKey.
    set this:message to pMessage.
    set this:selectionAction to pSelectionAction.
    set this:activeCondition to pActiveCondition.
    set this:selected to false.

    this:def("isAvailable", KateTaskMenuItem_isAvailable@).
    this:def("uiContent", KateTaskMenuItem_uiContent@).
    this:def("handleUiInput", KateTaskMenuItem_handleUiInput@).

    return this.
}

local function KateTaskMenuItem_isAvailable {
    parameter this.

    if this:activeCondition:isType("Boolean") {
        return this:activeCondition.
    } else if this:activeCondition:isType("KOSDelegate") {
        return this:activeCondition().
    } else {
        return true.
    }
}

local function KateTaskMenuItem_uiContent {
    parameter this.
    
    if this:message:isType("String") {
        return "[" + this:key + "]  " + this:message.
    } else if this:message:isType("KOSDelegate") {
        return "[" + this:key + "]  " + this:message().
    } else {
        return "_ERROR_BAD_TYPE_".
    }
}

local function KateTaskMenuItem_handleUiInput {
    parameter this, 
              runtime, 
              inputCharacter.
    
    if this:key = inputCharacter and this:isAvailable {
        this:selectionAction(runtime).
    }
}