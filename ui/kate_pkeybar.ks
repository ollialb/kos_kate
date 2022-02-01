@lazyglobal off.

include ("kate/core/kate_object").
include ("kate/ui/kate_pkey").

global function KatePKeyBar {
    parameter   id,
                pLeft,
                pTop,
                pStepX,
                pStepY.

    local this is KateObject("KatePKeyBar", id).

    set this:left to pLeft.
    set this:top to pTop.
    set this:stepX to pStepX.
    set this:stepY to pStepY.

    set this:pkeys to lexicon().

    this:def("drawUi", KatePKeyBar_drawUi@).
    this:def("addKey", KatePKeyBar_addKey@).
    this:def("removeKey", KatePKeyBar_removeKey@).
     
    return this.
}

local function KatePKeyBar_drawUi {
    parameter this.

    for key in this:pkeys:values {
        key:safeCall0("drawUi").
    }
}

local function KatePKeyBar_addKey {
    parameter this,
              pKey,
              pLabel,
              pStateDelegate is KatePKeyBar_noopHandler@,
              pPressedHandler is KatePKeyBar_noopHandler@.

    if this:pkeys:hasKey(pKey) {
        return this:pkeys[pKey].
    } else {
        local keyCount is this:pkeys:length.
        local newKey is KatePKey(pKey, pLabel, this:left + keyCount * this:stepX, this:top + keyCount * this:stepY, pStateDelegate, pPressedHandler).
        this:pkeys:add(pKey, newKey).
    }
}

local function KatePKeyBar_removeKey {
    parameter this,
              pKey.

     if this:pkeys:hasKey(pKey) {
        this:pkeys:remove(pKey).
    } else {
        // TODO
    }
}

local function KatePKeyBar_noopHandler {
    return PKEY_OFF.
}

