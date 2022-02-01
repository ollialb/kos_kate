@lazyGlobal off.

include ("kate/core/kate_object").

global STEERING_OFF is "OFF".
global STEERING_SAS_MODE is "SAS".
global STEERING_KOS_BUILTIN is "KOS".

global function KateSteering {
    parameter pShip is ship.
    local this is KateObject("KateSteering", pShip:name).

    set this:mode to STEERING_OFF.
    set this:oldSasMode to "STABILITYASSIST".

    this:def("enable", KateSteering_enable@).
    this:def("disable", KateSteering_disable@).
    this:def("getControlModule", KateSteering_getControlModule@).
    
    return this.
}

// ControlMode - TGT or KOS
// Active - boolean
local function KateSteering_enable {
    parameter   this,
                mode,
                newSasMode,
                newSteeringVector is V(0,0,0).

    local hasSas is getOrDefault(KATE:config:cpu, "sasControl", false).
    
    if mode = STEERING_SAS_MODE {
        local validTargetSasMode is ((newSasMode = "TARGET" or newSasMode = "ANTITARGET") and hasTarget).
        local validManeuverSasMode is (newSasMode = "MANEUVER" and hasNode).
        local validSasMode is (newSasMode = "PROGRADE" or newSasMode = "RETROGRADE" or newSasMode = "NORMAL" 
                                    or newSasMode = "ANTINORMAL" or newSasMode = "RADIALOUT" or newSasMode =  "RADIALIN" 
                                    or newSasMode =  "TARGET" or newSasMode =  "ANTITARGET" or newSasMode =  "MANEUVER" 
                                    or newSasMode =  "STABILITYASSIST" or newSasMode =  "STABILITY").
        if hasSas and (validTargetSasMode or validManeuverSasMode or validSasMode) {
            set this:mode to STEERING_SAS_MODE.
            set this:oldSasMode to sasMode.
            unlock steering.
            sas on.
            set sasMode to newSasMode.
            rcs off.
        } else {
            KATE:ui:setStatus("Cannot activate SAS with mode " + newSasMode).
            set this:mode to STEERING_KOS_BUILTIN.
            sas off.
            rcs on.
            lock steering to newSteeringVector.
        }
    } else {
        set this:mode to STEERING_KOS_BUILTIN.
        sas off.
        rcs on.
    }
}

local function KateSteering_disable {
    parameter   this.
    
    set this:mode to STEERING_OFF.
    unlock steering.
    set sasMode to "STABILITYASSIST".
    sas on.
    rcs off.
}

local function KateSteering_getControlModule {
    parameter   this.
    
    set allParts to ship:parts.

}