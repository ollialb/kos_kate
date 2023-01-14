@lazyGlobal off.

include("kate/core/kate_object").
include("kate/runtime/kate_process").

// A process wraps a particular task.
global function KateWarpAssist {
    parameter   pRuntime.

    local this is KateObject("KateWarpAssist", "KWA").
  
    set this:runtime to pRuntime.
    set this:nextWarp to TimeStamp(0).

    this:def("updateWarpPoints", KateWarpAssist_updateWarpPoints@).

    this:def("uiTitle", KateWarpAssist_uiTitle@).
    this:def("uiContent", KateWarpAssist_uiContent@).
    this:def("handleUiInput", KateWarpAssist_handleUiInput@).

    return this.
}

local function KateWarpAssist_updateWarpPoints {
    parameter this.
    
    local earliestTime is time + TimeSpan(2, 0, 0, 0, 0). // 2 years from now is the maximum we allow
    local warpAllowed is false.
    local warpInhibit is false.

    local runtime is this:runtime.
    for process in runtime:activeProcesses() {
        local t is process:warpPoint().
        if t < WARP_NONE {
            set warpInhibit to true.
        } else if t > WARP_NONE and t < earliestTime {
            set warpAllowed to true.
            set earliestTime to t.
        }
    }
    if warpInhibit {
        set this:nextWarp to WARP_INHIBIT.
    } else if warpAllowed {
        set this:nextWarp to earliestTime.
    } else {
        set this:nextWarp to WARP_NONE.
    }
}

local function KateWarpAssist_uiTitle {
    parameter this.
    if this:nextWarp > WARP_NONE {
        return "W".
    } else {
        return " ".
    }
}

local function KateWarpAssist_uiContent {
    parameter this.
    if this:nextWarp > WARP_NONE {
        return "W WARP".
    } else {
        return "      ".
    }
}

local function KateWarpAssist_handleUiInput {
   parameter   this,
                runtime,
                inputCharacter.

    if inputCharacter = "W" and this:nextWarp > WARP_NONE and kuniverse:timewarp:rate = 1 {
        kuniverse:timewarp:warpto(this:nextWarp:seconds).
    } else if kuniverse:timewarp:rate <> 1 {
        kuniverse:timewarp:cancelwarp().
    }
}