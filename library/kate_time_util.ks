@lazyGlobal off.

global function kate_prettyTime {
    parameter timeVal.

    if timeVal:isType("TimeStamp") {
        return kate_prettyTimeStamp(timeVal).
    } else if timeVal:isType("TimeSpan") {
        return kate_prettyTimeSpan(timeVal).
    } else if timeVal:isType("Scalar") {
        return kate_prettyTimeSpan(TimeSpan(timeVal)).
    } else {
        return "" + timeVal.
    }
}

local function kate_prettyTimeStamp {
    parameter timeVal.

    return timeVal:full.
}

local function kate_prettyTimeSpan {
    parameter timeVal.

    local result is "".
    local val is timeVal.
    if timeVal:seconds = 0 {
        return "now".
    } else if timeVal:seconds < 0 {
        set result to "-".
        set val to TimeSpan(-1*val:seconds).
    }

    if (val:year <> 0) {
        set result to result + val:year + "y".
    }
    if (val:day <> 0) {
        set result to result + val:day + "d".
    }
    if (val:hour <> 0) {
        set result to result + val:hour + "h".
    }
    if (val:minute <> 0) {
        set result to result + val:minute + "m".
    }
    set result to result + round(val:second,1) + "s".
    return result.
}