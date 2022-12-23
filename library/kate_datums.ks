@lazyGlobal off.

global UNIT_NONE is " ".
global UNIT_DENSITY is "kg/m3".
global UNIT_SPEED is "m/s".
global UNIT_ACCELERATION is "m/s2".
global UNIT_DISTANCE is "m".
global UNIT_TEMPERATURE is "K".
global UNIT_ATMOSPHERE is "atm".
global UNIT_HEATFLUX is "W/cm2".
global UNIT_DEGREE is "°".
global UNIT_FORCE is "N".
global UNIT_PERCENT is "%".
global UNIT_SECONDS is "s".

global function kate_prettyValue {
    parameter unit,
              value,
              afterCommaDigits is 2.

    local sgn is choose "-" if value < 0 else "".
    local val is abs(value).

    if val > 1E12 {
        return sgn + round(val / 1E12, afterCommaDigits) + " T" + unit.
    } else if val > 1E9 {
        return sgn + round(val / 1E9, afterCommaDigits) + " G" + unit.
    } else if val > 1E6 {
        return sgn + round(val / 1E6, afterCommaDigits) + " M" + unit.
    } else if val > 1E3 {
        return sgn + round(val / 1E3, afterCommaDigits) + " k" + unit.
    } else {
        return sgn + round(val, afterCommaDigits) + " " + unit.
    }
}

global function kate_datum {
    parameter id,
              unit,
              value,    // numerical
              digits is 2,
              total is 20.

    local result is id + " " + kate_prettyValue(unit, value, digits).
    if result:length < total {
        return result:padright(total).
    } else if result:length > total {
        return result:substring(0, total).
    } else {
        return result.
    }
}
