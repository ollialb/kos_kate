@lazyglobal off.

include ("kate/core/kate_object").

global PKEY_OFF is 0.
global PKEY_LOW is 1.
global PKEY_MED is 2.
global PKEY_HIGH is 3.

local PKEY_SCALE is " ░▓█". //SOFTKEY_OFF + SOFTKEY_LOW + SOFTKEY_MED + SOFTKEY_HIGH.

global function KatePKey {
    parameter   pKey,
                pLabel,
                pLeft,
                pTop,
                pStateDelegate is KatePKey_defaultStateDelegate@,
                pPressedHandler is KatePKey_defaultPressedHandler@.

    local this is KateObject("KatePKey", "PKEY_" + pKey).

    set this:left to pLeft.
    set this:top to pTop.
    set this:label to pLabel.
    set this:key to pKey.
    set this:state to PKEY_OFF.
    set this:stateDelegate to pStateDelegate.
    set this:pressedHandler to pPressedHandler.

    this:def("drawUi", KatePKey_drawUi@).
    this:def("onPressed", KatePKey_onPressed@).
     
    return this.
}

local function KatePKey_drawUi {
    parameter this.

    set this:state to PKEY_SCALE[max(PKEY_OFF, min(PKEY_HIGH, this:stateDelegate()))].
    print this:state + this:key + " " + this:label + this:state at (this:left, this:top).
}

local function KatePKey_onPressed {
    parameter this.
    this:pressedHandler().
}

local function KatePKey_defaultStateDelegate {
    return PKEY_OFF.
}

local function KatePKey_defaultPressedHandler {
    // Nothing
}


