@lazyGlobal off.

global function kate_compassHeading {
    parameter pHeading.
    local hdg is mod(pHeading, 360).
    if hdg < 0 return 360 + hdg.
    else       return hdg.
}

// Formatted to 20 chars width
global function kate_prettyGeoposition {
    parameter geoPos.
    return kate_prettyLatitude(geoPos):padleft(9) + kate_prettyLongitude(geoPos):padleft(11).
}

global function kate_prettyLatitude {
    parameter geoPos.
    if (geoPos:istype("GeoCoordinates")) {
        local latitudeDMS is kate_toDMS(geoPos:lat).
        return latitudeDMS + "" + (choose "N" if geoPos:lat >= 0 else "S").
    } else {
        return "undef latitude".
    }
}

global function kate_prettyLongitude {
    parameter geoPos.
    if (geoPos:istype("GeoCoordinates")) {
        local longitudeDMS is kate_toDMS(geoPos:lng).
        return longitudeDMS + "" + (choose "E" if geoPos:lng >= 0 else "W").
    } else {
        return "undef latitude".
    }
}

local function kate_toDMS {
    parameter coordinate.

    local absolute is abs(coordinate).
    local degrees is floor(absolute).
    local minutesNotTruncated is (absolute - degrees) * 60.
    local minutes is floor(minutesNotTruncated).
    local seconds is floor((minutesNotTruncated - minutes) * 60).

    return degrees + "°" + minutes + "'" + seconds.
}

// Haversine formula for creat circle distance on spherical bodies.
global function kate_greatCircleDistance {
    parameter pos1, pos2. // GeoCoordinates
              
    local lat1 is pos1:lat.
    local lng1 is pos1:lng.
    local lat2 is pos2:lat.
    local lng2 is pos2:lng.
    local r is ship:body:radius.

    local havLat is sin((lat2-lat1)/2)^2.
    local havLng is cos(lat1) * cos(lat2) * sin((lng2-lng1)/2)^2.
    local havTerm is arcSin(sqrt(havLat + havLng)) * constant:degtorad.

    return 2 * r * havTerm. 
}

// Haversine formula for creat circle distance on spherical bodies.
global function kate_greatCircleAzimuth {
    parameter pos1, pos2. // GeoCoordinates
              
    local lat1 is pos1:lat.
    local lng1 is pos1:lng.
    local lat2 is pos2:lat.
    local lng2 is pos2:lng.
    local deltalng is lng2-lng1.

    return arcTan2(sin(deltalng) * cos(lat2), cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltalng)). 
}

// Based on Kepler equation, time from periapsis to given radius.
// t(r) = sqrt(a3 / μ) * [2 * atan(sqrt((r - a * (1 - e)) / (a * (1 + e) - r))) - sqrt(e2 - (1 - r / a)2 )]
global function kate_timeOfAltitude {
    parameter pTargetAltitude,
              pVessel is ship.

    local pe is pVessel:orbit:periapsis + pVessel:body:radius.
    local ap is pVessel:orbit:apoapsis + pVessel:body:radius.
    local a is pVessel:orbit:semimajoraxis.
    local b is pVessel:orbit:semiminoraxis.
    local e is pVessel:orbit:eccentricity.
    local r is pTargetAltitude + pVessel:body:radius.
    local mu is pVessel:body:mu.

    if r <= ap and r >= pe {
        return sqrt((a^3)/mu) * (2 * arcTan(sqrt((r - a * (1 - e)) / (a * (1 + e) - r)))*constant:degtorad - sqrt(e^2 - (1 - r / a)^2)).
    } else {
        return 1E12.
    }
}