@lazyGlobal off.

include ("kate/core/kate_object").

global function KateShip {
    parameter pShip is ship.
    local this is KateObject("KateShip", pShip:name).

    set this:ownship to pShip.
    set this:boundsBox to 0.
    set this:facingArea to 0.

    set this:throttle to 0.

    this:def("totalThrust", KateShip_totalThrust@).
    this:def("possibleThrust", KateShip_possibleThrust@).
    this:def("deployGear", KateShip_deployGear@).
    this:def("detectLaunchClamps", KateShip_detectLaunchClamps@).
    this:def("releaseLaunchClamps", KateShip_releaseLaunchClamps@).
    this:def("detectFairings", KateShip_detectFairings@).
    this:def("deployFairings", KateShip_deployFairings@).
    this:def("hasDepletedEnginesInCurrentStage", KateShip_hasDepletedEnginesInCurrentStage@).
    this:def("detectAirbrakes", KateShip_detectAirbrakes@).
    this:def("deployAirbrakes", KateShip_deployAirbrakes@).
    this:def("deployChutes", KateShip_deployChutes@).
    this:def("invalidateBounds", KateShip_invalidateBoundss@).
    this:def("bounds", KateShip_bounds@).
    this:def("radarAltitude", KateShip_radarAltitude@).
    this:def("areaPrograde", KateShip_areaPrograde@).
    this:def("surfaceHeading", KateShip_surfaceHeading@).
    this:def("engageAfterburners", KateShip_engageAfterburners@).
    this:def("activeAfterburners", KateShip_activeAfterburners@).
    this:def("getAllEngines", KateShip_getAllEngines@).
    this:def("hasAirbreathingEngines", KateShip_hasAirbreathingEngines@).
    this:def("activateOtherLocalProcessors", KateShip_activateOtherLocalProcessors@).
    this:def("otherLocalProcessorsActive", KateShip_otherLocalProcessorsActive@).
    
    return this.
}

local function KateShip_getAllEngines {
    parameter this.

    local allEngines is list().
    list ENGINES in allEngines.

    local stageEngines is list().
    for engine in allengines {
        local activeStage is choose this:ownship:stagenum-1 if (this:ownship:status = "PRELAUNCH" or this:ownship:status = "LANDED") else this:ownship:stagenum.
        if engine:stage = activeStage {
            stageEngines:add(engine).
        }
    }
    return stageEngines.
}

local function KateShip_hasAirbreathingEngines {
    parameter this.

    for part in this:getAllEngines() {
        if part:consumedresources:hasKey("Intake Air") return true.
    }
    return false.
}

local function KateShip_engageAfterburners {
    parameter this,
              engage.

    for part in this:getAllEngines() {
        if part:multimode {
			local mode is part:mode.
            if (mode = "Dry" and engage) or (mode = "Wet" and not engage) {
                part:togglemode.
            }
		}
    }
}

local function KateShip_activeAfterburners {
    parameter this.

    for part in this:getAllEngines() {
        if part:multimode and part:mode = "Wet" return true.
    }
    return false.
}

local function KateShip_totalThrust {
    parameter this.

    local totalThrust is V(0,0,0).
    for eng in this:getAllEngines() {
        set totalThrust to totalThrust + eng:thrust * eng:facing:vector.
    }
    return totalThrust.
}

local function KateShip_possibleThrust {
    parameter this.

    local possibleThrust is 0.
    for eng in this:getAllEngines() {
        set possibleThrust to possibleThrust + eng:possibleThrust.
    }
    return possibleThrust.
}

local function KateShip_invalidateBoundss {
    parameter   this.

    set this:boundsBox to 0.
    set this:facingArea to 0.
}

local function KateShip_deployGear {
    parameter   this,
                state.
                
    if (state and not gear) {gear on.   this:invalidateBounds(). }
    if (not state and gear) {gear off.  this:invalidateBounds(). }
}


local function KateShip_detectLaunchClamps {
    parameter   this.
    
    local result is list().
    for part in this:ownship:parts {
        if (part:isType("LaunchClamp")) {
            result:add(part).
        }
    }
    return result.
}

local function KateShip_releaseLaunchClamps {
    parameter   this,
                clampParts. // list of Parts
    
    for part in clampParts {
        local clampModule is part:getModule("LaunchClamp").
        clampModule:doEvent("release clamp").
    }
}

local function KateShip_detectFairings {
    parameter   this.
    
    local result is list().
    for part in this:ownship:parts {
		// for stock fairings
		if part:hasmodule("moduleproceduralfairing") {
			result:add(part).
		}
		// for 'procedural fairings' mod
		if part:hasmodule("proceduralfairingdecoupler") {
			result:add(part).
		}
    }
    return result.
}

local function KateShip_deployFairings {
    parameter   this,
                fairingParts. // list of Parts
    for part in fairingParts {
		// for stock fairings
		if part:hasmodule("moduleproceduralfairing") {
			local decoupler is part:getmodule("moduleproceduralfairing").
			if decoupler:hasevent("deploy") {
				decoupler:doevent("deploy").
			}
		}

		// for 'procedural fairings' mod
		if part:hasmodule("proceduralfairingdecoupler") {
			local decoupler is part:getmodule("proceduralfairingdecoupler").
			if decoupler:hasevent("jettison fairing") {
				decoupler:doevent("jettison fairing").
			}
		}
	}
}

local function KateShip_hasDepletedEnginesInCurrentStage {
    parameter   this.
    
    local allEngines is list().
    list ENGINES in allEngines.

    for eng in allEngines {
        if eng:ignition and eng:flameout {
            return true.
        }
    }
    return false.
}

local function KateShip_detectAirbrakes {
    parameter   this.
    
    return ship:partsnamed("airbrake1").
}

local function KateShip_deployAirbrakes {
    parameter   this,
                airbrakeParts,   // list of Parts
                brakesOn,       // boolean
                useControls.    // boolean

    if (brakesOn) { brakes on. } else { brakes off. }.

    for part in airbrakeParts {
		local aero is part:getmodule("moduleaerosurface").
        if useControls {
            aero:doaction("activate all controls", true).
        } else {
            aero:doaction("deactivate all controls", true).
        }
	}
}

local function KateShip_deployChutes {
    parameter   this,
                chutesOn.

    if (chutesOn) { chutessafe on. } else { chutessafe off. }.
}

local function KateShip_bounds {
    parameter   this.

    if this:boundsBox = 0 { 
        set this:boundsBox to ship:bounds.
    }
    return this:boundsBox.
}

local function KateShip_radarAltitude {
    parameter   this.
    local boundsRadar is this:bounds():bottomaltradar.
    local cogAltitude is ship:altitude - ship:geoposition:terrainheight.
    return min(cogAltitude, boundsRadar).
}

local function KateShip_areaPrograde {
    parameter   this.

    if this:facingArea = 0 {
        local shipBounds is this:bounds().
        local minVec is shipBounds:relMin.
        local maxVec is shipBounds:relMax.
        local lateralMin is vectorExclude(shipBounds:facing:vector, minVec).
        local lateralMax is vectorExclude(shipBounds:facing:vector, maxVec).

        // Assume a circular area to be average of min and max distance
        set this:facingArea to (lateralMin:mag + lateralMax:mag)^2 / 4 * constant:pi.
    }
    return this:facingArea.
}

local function KateShip_surfaceHeading {
    parameter this.

    local vel_x is vDot(heading(90, 0):vector, ship:srfprograde:vector).
    local vel_y is vDot(heading( 0, 0):vector, ship:srfprograde:vector).

    return mod(arcTan2(vel_x, vel_y)+360, 360).
}

local function KateShip_activateOtherLocalProcessors {
    parameter   this,
                newState.

    local allProcessors is list().

    list PROCESSORS in allProcessors.
    for proc in allProcessors {
        if proc:tag <> core:tag and proc:part:ship = this:ownship {
            if not newState and proc:mode <> "OFF" {
                proc:deactivate().
            } else if  newState and proc:mode = "OFF" {
                proc:activate().
            }
        }
    }
}

local function KateShip_otherLocalProcessorsActive {
    parameter   this.

    local allProcessors is list().

    list PROCESSORS in allProcessors.
    for proc in allProcessors {
        if proc:tag <> core:tag and proc:part:ship = this:ownship {
            if proc:mode <> "OFF" {
                return true.
            }
        }
    }
    return false.
}
