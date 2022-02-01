@lazyGlobal off.

include ("kate/core/kate_object").

global function KateAveragedValue {
    parameter name, pHistorySize, pDefaultValue.
    local this is KateObject("KateAveragedValue", name).

    set this:defaultValue to pDefaultValue.
    set this:historySize to pHistorySize.
    set this:history to queue().

    this:def("setLastValue", KateDampedValue_setLastValue@).
    this:def("averageValue", KateDampedValue_averageValue@).
    
    return this.
}

local function KateDampedValue_setLastValue {
    parameter   this, value.
    this:history:push(value).
    if this:history:length > this:historySize {
        this:history:pop().
    }
}

local function KateDampedValue_averageValue {
    parameter   this.
    if this:history:empty {
        return this:defaultValue.
    } else {
        local sum is this:defaultValue.
        for value in this:history {
            set sum to sum + value.
        }
        return sum * (1/this:history:length).
    }
}