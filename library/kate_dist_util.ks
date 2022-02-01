@lazyGlobal off.

include("kate/library/kate_datums").

global function kate_prettyDistance {
    parameter distVal,
              afterCommaDigits is 2.

    return kate_prettyValue("m", distVal, afterCommaDigits).
}

global function kate_prettySpeed {
    parameter speedVal,
              afterCommaDigits is 2.

    return kate_prettyValue("m/s", speedVal, afterCommaDigits).
}

global function kate_prettyAccel {
    parameter accVal,
              afterCommaDigits is 2.

    return kate_prettyValue("m/s²", accVal, afterCommaDigits).
}

global function kate_prettyTemp {
    parameter tempVal,
              afterCommaDigits is 2.

    return kate_prettyValue("K", tempVal, afterCommaDigits).
}