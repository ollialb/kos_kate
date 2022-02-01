@lazyGlobal off.

include ("kate/core/kate_object").
include ("kate/library/kate_datums").

// Taken from: https://arc.aiaa.org/doi/full/10.2514/1.J060153
// and https://spacecraft.ssl.umd.edu/academics/791S20/791S16L16.aerothermx.pdf 
global function kate_AtmosphereAt {
    parameter pAltitude,
              pSpeed,
              pShipArea is 10, //m^2
              pBody is body.

    local this is lexicon().

    // Assume the ship has a very blunt "tip" facing the atmosphere.
    // This is true for heat shields, but not in case of naked structure!
    local shipRadius is sqrt(pShipArea) / constant:pi.
    local noseRadius is shipRadius * 10.

    set this:molMass to                 pBody:atm:molarmass.
    //set this:specGasConst to            8.31446261815324 / this:molMass.
    set this:specGasConst to            constant:idealGas / this:molMass.
    set this:temperature to             pBody:atm:altitudetemperature(pAltitude).
    set this:pressure to                pBody:atm:altitudepressure(pAltitude) * constant:atmtokpa * 1000. // Pa
    set this:adiabaticIndex to          pBody:atm:adiabaticindex.
    if (this:temperature > 0) {
        set this:density to             this:pressure / (this:specGasConst * this:temperature).
        set this:speedOfSound to        sqrt(this:adiabaticIndex * this:specGasConst * this:temperature).
        set this:machNumber to          pSpeed / this:speedOfSound.
        set this:heatFlux to            1.7E-4 * ((abs(this:density/noseRadius))^0.5) * (pSpeed^3). // W/m2
        set this:wallTemperature to     (this:heatFlux / (0.8 * 5.67E-8))^0.25.
        set this:dynamicPressure to     0.5 * this:density * (pSpeed^2) * 10.
    } else {
        set this:density to 0.
        set this:speedOfSound to 0.
        set this:machNumber to 0.
        set this:stagnationHeatFlux to  0.
        set this:heatFlux to 0.
        set this:wallTemperature to 0.
        set this:dynamicPressure to 0.
    }

    return this.
}

global function kate_prettyAtmosphere {
    parameter   atmos, result.

    result:add(kate_datum("OAT", UNIT_TEMPERATURE, atmos:temperature)     + kate_datum("Rho", UNIT_DENSITY, atmos:density)                                   + kate_datum(" Ma", UNIT_NONE, atmos:machNumber)).
    result:add(kate_datum("WLT", UNIT_TEMPERATURE, atmos:wallTemperature) + kate_datum("  Q", UNIT_ATMOSPHERE, atmos:dynamicpressure*constant:kpatoatm*1E-3) + kate_datum("Qfx", UNIT_HEATFLUX, atmos:heatFlux*1E-4)).
}

// Returns the altitude from which and above the density less than 0.00025 kg/m3 or as given by the client.
global function kate_nearVacuumAltitude {
    parameter   pBody is body,
                pDensityLimit is 0.00025. // kg/m3

    local specGasConst is constant:idealGas / pBody:atm:molarmass.

    local curAltitude is altitude.
    local curDensity is 100000000.
    until curDensity <= pDensityLimit {
        set   curAltitude    to curAltitude + 100.
        local curTemperature is pBody:atm:altitudetemperature(curAltitude).
        if (curTemperature > 0) {
            local curPressure    is body:atm:altitudepressure(curAltitude) * constant:atmtokpa * 1000.
            set   curDensity     to curPressure / (specGasConst * curTemperature).
        } else {
            set   curDensity     to 0.
        }
    }
    return min(pBody:atm:height, curAltitude).
}