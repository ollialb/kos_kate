@lazyGlobal off.

global function kate_orbitInfo {
    parameter orb is ship:orbit.

    local trans is obt:transition.

    if trans = "FINAL" {
        return orb:name + " - Ap " + round(orb:apoapsis/1000, 1) + " km - Pe " + round(orb:periapsis/1000, 1).
    } else if orb:eccentricity >= 1 {
        return orb:name + " - Ap " + round(orb:apoapsis/1000, 1) + " km - Pe " + round(orb:periapsis/1000, 1).
    } else {
        return "".
    }
}

// function kate_impact_height {
//     local impactuts is kate_impact_uts().
//     return  kate_ground_track(positionat(ship, impactuts), impactuts):terrainheight.
// }

// returns the uts of the ship's impact, note: only works for non hyperbolic orbits
function kate_impact_uts {
    parameter craftorbit is ship:orbit.

	local starttime is time:seconds.
	local sma is craftorbit:semimajoraxis.
	local ecc is craftorbit:eccentricity.
	local craftta is craftorbit:trueanomaly.
	local orbitperiod is craftorbit:period.
	local ap is craftorbit:apoapsis.
	local pe is craftorbit:periapsis.
	local impactuts is kate_time_betwene_two_ta(
        ecc, orbitperiod, craftta,
        alt_to_ta(sma, ecc, ship:body, max(min(0, ap - 1), pe + 1)) [1]) 
        + starttime.
	return impactuts.
}

// returns a list of the true anomalies of the 2 points where the craft's orbit passes the given altitude
function alt_to_ta {
	parameter sma, ecc, bodyin, altin.
	local rad is altin + bodyin:radius.
	local taofalt is arccos((-sma * ecc^2 + sma - rad) / (ecc * rad)).
	return list(taofalt, 360-taofalt). //first true anomaly will be as orbit goes from pe to ap
}

// returns the difference in time between 2 true anomalies, traveling from tadeg1 to tadeg2
function kate_time_betwene_two_ta {
	parameter ecc, periodin, tadeg1, tadeg2.
	
	local madeg1 is kate_ta_to_ma(ecc,tadeg1).
	local madeg2 is kate_ta_to_ma(ecc,tadeg2).
	
	local timediff is periodin * ((madeg2 - madeg1) / 360).
	
	return mod(timediff + periodin, periodin).
}

// converts a true anomaly(degrees) to the mean anomaly (degrees) note: only works for non hyperbolic orbits
function kate_ta_to_ma {
	parameter ecc, tadeg.
	local eadeg is arctan2(sqrt(1-ecc^2) * sin(tadeg), ecc + cos(tadeg)).
	local madeg is eadeg - (ecc * sin(eadeg) * constant:radtodeg).
	return mod(madeg + 360,360).
}

// returns the geocoordinates of the ship at a given time(uts) adjusting for planetary rotation over time, only works for non tilted spin on bodies 
function kate_ground_track {	
	parameter pos,postime,localbody is ship:body.
	local bodynorth is v(0,1,0). // using this instead of localbody:north:vector because in many cases the non hard coded value is incorrect
	local rotationaldir is vdot(bodynorth,localbody:angularvel) * constant:radtodeg. // the number of degrees the body will rotate in one second
	local poslatlng is localbody:geopositionof(pos).
	local timedif is postime - time:seconds.
	local longitudeshift is rotationaldir * timedif.
	local newlng is mod(poslatlng:lng + longitudeshift,360).
	if newlng < - 180 { set newlng to newlng + 360. }
	if newlng > 180 { set newlng to newlng - 360. }
	return latlng(poslatlng:lat,newlng).
}