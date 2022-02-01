@lazyglobal off.

include ("kate/core/kate_object").

global function KateCommand {
    parameter   id,
                pMnemonic,
                pHandler, // delegate
                pArguments.

    local this is KateObject("KateCommand", id).

    set this:mnemonic to pMnemonic.
    set this:key to pKey.
    set this:handler to pHandler.
    set this:arguments to pArguments.

    this:def("uiContent", KateSoftKey_uiContent@).
    this:def("handleUiInput", KateSoftKey_handleUiInput@).
     
    return this.
}

local function KateSoftKey_uiContent {
    parameter this.
    
}

local function KateSoftKey_handleUiInput {
    parameter this,
              runtime,
              pKey.
}