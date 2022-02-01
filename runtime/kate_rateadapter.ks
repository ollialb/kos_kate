@lazyGlobal off.

include("kate/core/kate_object").

local MAX_IPU is 2000.
local MIN_IPU is 50.
local IPU_INCREMENT is 50.
local TIME_HYSTERESIS_UP is 0.001.
local TIME_HYSTERESIS_DOWN is 0.05.

global function KateRateAdapter {
    local this is KateObject("KateRateAdapter", "KRA").

    set this:lastUpdate to time.
    
    this:def("update", KateRateAdapter_update@).
    
    return this.
}

local function KateRateAdapter_update {
    parameter this,
              scheduledTimeInterval.

    local now is time. 
    local scheduledTimeSpan is TimeSpan(scheduledTimeInterval).
    local timeSinceLastUpdate is now - this:lastUpdate.
    set this:lastUpdate to time.
    if scheduledTimeSpan < timeSinceLastUpdate + TIME_HYSTERESIS_UP {
        print "TOO SLOW" at (20,26).
        set config:ipu to max(50, min(MAX_IPU, config:ipu + IPU_INCREMENT)).
    } else if scheduledTimeSpan > timeSinceLastUpdate + TIME_HYSTERESIS_DOWN {
        print "TOO FAST" at (20,27).
        set config:ipu to max(50, min(MAX_IPU, config:ipu - IPU_INCREMENT)).
    }
}