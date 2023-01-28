@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/ui/kate_window").
include ("kate/ui/kate_window2").
include ("kate/ui/kate_pkey").
include ("kate/ui/kate_pkeybar").

local K_VERS is "0.8.2".
local MAX_STATUS_MESSAGE_AGE is TimeSpan(5).
local TASK_AREA_TOP is 14.

global PKEYBAR_TOP is 0.
global PKEYBAR_UPPER_LEFT is 1.
global PKEYBAR_UPPER_RIGHT is 2.

global function KateUi {
    parameter runtime.
    local this is KateObject("KateUi", "KATEUI").

    set this:focussedModule to "".
    set this:blink to true.
    set this:clockMet to true.
    set this:active to false.
    set this:needsCompleteRefresh to false.
    set this:moduleOffset to 5.
    set this:processWindows to list().
    set this:status to "".
    set this:statusTime to time.
    set this:moduleRows to 1.
    set this:standby to ship:status <> "PRELAUNCH".
    set this:shellUpdateToken to 0.

    set this:moduleKeyBar to KatePKeyBar("ModulePKeyBar", 0, 2, 0, 2).
    set this:taskKeyBar to KatePKeyBar("TaskPKeyBar", 54, 2, 0, 2).

    set this:init to KateUi_init@:bind(this).
    set this:update to KateUi_update@:bind(this).
    set this:react to KateUi_react@:bind(this).
    set this:addProcess to KateUi_addProcess@:bind(this).
    set this:removeProcess to KateUi_removeProcess@:bind(this).
    set this:refresh to KateUi_refresh@:bind(this).

    set this:drawStandby to KateUi_drawStandby@:bind(this):bind(runtime).
    set this:drawMainFrame to KateUi_drawMainFrame@:bind(this):bind(runtime).
    set this:drawMainContent to KateUi_drawMainContent@:bind(this):bind(runtime).
    set this:focussedModuleReact to KateUi_focussedModuleReact@:bind(this):bind(runtime).
    set this:drawShell to KateUi_drawShell@:bind(this):bind(runtime).

    this:def("setStatus", KateUi_setStatus@).

    return this.
}

local function KateUi_init {
    parameter this,
              runtime.

    clearscreen.
    set terminal:width to 62.
    set terminal:height to 30.

    set this:lastUpdateTime to time.
    set this:lastBlinkTime to time.
    set this:lastClockTime to time.

    set this:focussedModuleWindow to KateWindow2("FocussedModule", 
        10, 2, 42, 11, 
        KateUi_getFocussedModuleTitle@:bind(this):bind(runtime), 
        KateUi_getFocussedModuleContent@:bind(this):bind(runtime)).

    local moduleIds is runtime:moduleIds.
    for moduleId in moduleIds {
        this:moduleKeyBar:addKey(moduleId[0], moduleId:substring(0, 4), 
            KateUi_getModulePKeyState@:bind(this):bind(runtime):bind(moduleId),
            KateUi_handleModulePKeyPressed@:bind(this):bind(runtime):bind(moduleId)).
    }
}

local function KateUi_getModulePKeyState {
    parameter this,
              runtime,
              moduleId.

    local modules is runtime:modules.
    local module is modules[moduleId].
        
    if this:focussedModule = moduleId {
        if module:activeTasks > 0 and this:blink {
            return PKEY_HIGH.
        } else {
            return PKEY_MED.
        }
    } else {
        if module:activeTasks > 0 and this:blink {
            return PKEY_LOW.
        }
    }
    return PKEY_OFF.
}

local function KateUi_handleModulePKeyPressed {
    parameter this,
              runtime,
              moduleId.
    return this:focussedModule.
}

local function KateUi_react {
    parameter this,
              runtime.

    if (terminal:input:haschar) {
        local ch is terminal:input:getchar().
        if ch = "Q" {
            if this:standby {
                runtime:quit().
            } else {
                runtime:requestStandby(true).
                set this:standby to true.
                set this:needsCompleteRefresh to true.
            }
        }
        else if ch = "M" {
            toggle mapView.
        }
        else if ch = "X" {
            runtime:abortProcesses().
        }
        else if ch = "W" {
            runtime:warpAssist:safeCall2("handleUiInput", runtime, ch).
        }
        else if this:standby {
            set this:standby to false.
            runtime:requestStandby(false).
            this:refresh().
        }

        if not this:standby {
            local moduleIds is runtime:moduleIds.
            for moduleId in moduleIds {
                if ch = moduleId[0] {
                    set this:focussedModule to moduleId.
                    set this:needsCompleteRefresh to true.
                }
            }
            this:focussedModuleReact(ch). 
        }
    }
}

local function KateUi_refresh {
    parameter this.
    set this:needsCompleteRefresh to true.
}

local function KateUi_update {
    parameter this,
              runtime.

    if not this:active {
        this:init(runtime).
        if this:standby {
            runtime:requestStandby(true).
        }
        local modulesIterator is runtime:moduleIds:iterator.
        if modulesIterator:next {
            set this:focussedModule to modulesIterator:value.
        }
        set this:active to true.
        set this:needsCompleteRefresh to true.
    }

    if this:needsCompleteRefresh {
        clearscreen.
        this:drawMainFrame().
        if not this:standby {
            this:focussedModuleWindow:drawFrame().
            local winPos is TASK_AREA_TOP.
            for processWindow in this:processWindows {
                set processWindow:top to winPos.
                processWindow:drawFrame().
                set winPos to winPos + processWindow:height.
            }
        }
        set this:needsCompleteRefresh to false.
    }
    
    local now is time.
    if now < this:lastUpdateTime + 0.25 return.
    set this:lastUpdateTime to now.

    if now > this:lastBlinkTime + 1.0 {
        set this:blink to (not this:blink).
        set this:lastBlinkTime to now.
    }

    if now > this:lastClockTime + 4.0 {
        set this:clockMet to (not this:clockMet).
        set this:lastClockTime to now.
    }
    
    this:drawMainContent().
    this:drawShell().

    if not this:standby {
        this:moduleKeyBar:safeCall0("drawUi").
        this:focussedModuleWindow:drawContent().

        for processWindow in this:processWindows {
            processWindow:drawContent().
        }
    } else {
        this:drawStandby().
    }
}

local function KateUi_drawStandby {
    parameter this,
              runtime.

    print "╔═══════════════════════════════════════╗" at (10, 19).
    print "║             S T A N D B Y             ║" at (10, 20).
    print "╚═══════════════════════════════════════╝" at (10, 21).
}

local function KateUi_drawMainFrame {
    parameter this,
              runtime.

    // TEMPLATE
    // 1234567890
    // A[B]RE S ║
    //               1         2         3         4         5         6
    //     01234567890123456789012345678901234567890123456789012345678901
    print " [KATE] │                                            │ V0.8.4 " at (0, 0).
    print "════════╬════════════════════════════════════════════╬════════" at (0, 1).
    print "        │ MODULES                                    │        " at (0, 2).
    print "────────╣                                            ╠────────" at (0, 3).
    print "        │                                            │        " at (0, 4).
    print "────────╣                                            ╠────────" at (0, 5).
    print "        │                                            │        " at (0, 6).
    print "────────╣                                            ╠────────" at (0, 7).
    print "        │                                            │        " at (0, 8).
    print "────────╣                                            ╠────────" at (0, 9).
    print "        │                                            │        " at (0, 10).
    print "────────╣                                            ╠────────" at (0, 11).
    print "        │                                            │        " at (0, 12).
    print "════════╬════════════════════════════════════════════╬════════" at (0, 13).
    print "        │ TASKS                                      │        " at (0, 14).
    print "────────╣                                            ╠────────" at (0, 15).
    print "        │                                            │        " at (0, 16).
    print "────────╣                                            ╠────────" at (0, 17).
    print "        │                                            │        " at (0, 18).
    print "────────╣                                            ╠────────" at (0, 19).
    print "        │                                            │        " at (0, 20).
    print "────────╣                                            ╠────────" at (0, 21).
    print "        │                                            │        " at (0, 22).
    print "────────╣                                            ╠────────" at (0, 23).
    print "        │                                            │        " at (0, 24).
    print "════════╬════════════════════════════════════════════╬════════" at (0, 25).
    print " X CNCL │                                            │ M MAPV " at (0, 26).
    print "────────╣                                            ╠────────" at (0, 27).
    print " Q QUIT │ >                                          │        " at (0, 28).
    if not this:standby print "STBY" at (3, 28).

    set this:shellUpdateToken to 0. // Refresh shell next time
}

local function KateUi_drawMainContent {
    parameter this,
              runtime.
    
    local now is time:full.
    if this:clockMet {
        set now to "MET " + Time(missionTime):full.
    }
    
    local sysInfo is ("M" + runtime:messageQueue:messageCount() + " P" + runtime:messageQueue:messageCount() + " @" + config:ipu). 
    print sysinfo:padright(14) + now:padleft(28) at (10, 0).

    local warpKey is runtime:warpAssist:safeCall0("uiContent").
    print warpKey at (55, 28).

    //if time - this:statusTime > MAX_STATUS_MESSAGE_AGE {
    //    this:setStatus("").
    //}
    //print this:status:padRight(40) at (10, 26).
}

local function KateUi_drawShell {
    parameter this,
              runtime.
    
    local shell is runtime:shell.
    if (this:shellUpdateToken = shell:changeToken) return 0.

    local output is shell:output.
    local command is shell:currentCommand().
    print output[0]:padright(40) at (10, 26).
    print output[1]:padright(40) at (10, 27).
    print ("> " + command):padright(40) at (10, 28).
    set this:shellUpdateToken to shell:changeToken.
}

local function KateUi_setStatus {
    parameter this,
              status.
    
    set this["status"] to status.
    set this:statusTime to time.
}

local function KateUi_getFocussedModuleTitle {
    parameter this,
              runtime.
    return "█ " + this:focussedModule.
}

local function KateUi_getFocussedModuleContent {
    parameter this,
              runtime.
    local moduleId is this:focussedModule.
    local modules is runtime:modules.
    if modules:haskey(moduleId) {
        local module is modules[moduleId].
        return module:safeCall0("uiContent").
    } else {
        local emptyList is list().
        return emptyList.
    }
}

local function KateUi_focussedModuleReact {
    parameter this,
              runtime,
              inputCharacter.
    local moduleId is this:focussedModule.
    local modules is runtime:modules.
    if modules:haskey(moduleId) {
        local module is modules[moduleId].
        return module:safeCall2("handleUiInput", runtime, inputCharacter).
    } else {
        local emptyList is list().
        return emptyList.
    }
}

local function KateUi_addProcess {
    parameter this,
              process,
              windowContentHeight.

    local newProcessWindow is KateWindow2("ProcWindow_" + process:id, 
        10, TASK_AREA_TOP, 42, windowContentHeight + 3, 
        process:uiTitle@, 
        process:uiContent@).

    this:processWindows:add(newProcessWindow).
    set this:needsCompleteRefresh to true.
}

local function KateUi_removeProcess {
    parameter this,
              process.

    local foundWindow is 0.
    for processWindow in this:processWindows {
        if processWindow:id = "ProcWindow_" + process:id {
            set foundWindow to processWindow.
        }
    }

    if (foundWindow <> 0) {
        local index is this:processWindows:find(foundWindow).
        this:processWindows:remove(index).
    }

    set this:needsCompleteRefresh to true.
}
