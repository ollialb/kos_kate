@lazyGlobal off.

include("kate/core/kate_object").
include("kate/modules/kate_task_menu_item").

// drawUi (offX, offY)
global function KateTaskMenu {
    local this is KateObject("KateTaskMenu", "Menu").

    set this:items to list().

    this:def("addItem", KateTaskMenu_addItem@).
    this:def("uiContent", KateTaskMenu_uiContent@).
    this:def("handleUiInput", KateTaskMenu_handleUiInput@).

    return this.
}

local function KateTaskMenu_addItem {
    parameter this,
              pKey,                         // Single character string
              pMessage,                     // String or delegate returning a string
              pSelectionAction,             // Delegate which is called, when the given key was selected and the action was available
              pActiveCondition is true.     // Boolean or delegate returning a boolean
    
    local newEntry is KateTaskMenuItem(pKey, pMessage, pSelectionAction, pActiveCondition).
    this:items:add(newEntry).
}

local function KateTaskMenu_uiContent {
    parameter this.
    
    local result is list().

    for item in this:items {
        if item:isAvailable() {
            result:add(item:uiContent()).
        }
    }

    return result.
}

local function KateTaskMenu_handleUiInput {
    parameter this, 
              runtime, 
              inputCharacter.
    
    for item in this:items {
        item:handleUiInput(runtime, inputCharacter).
    }
}