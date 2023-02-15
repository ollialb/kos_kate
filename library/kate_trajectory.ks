@lazyGlobal off.

include ("kate/library/kate_atmosphere").

// Assuming no lift and drag in retrograde direction
local function kate_atmosphericForceVector {
    parameter   pVelocity, // Vector
                pAtmosphere, // from kate_AtmosphereAt
                pShipArea is 10.

    local dragCoefficient is 0.1.
    local drag is dragCoefficient * pAtmosphere:dynamicPressure * pShipArea.
    local dragVector is -drag * pVelocity:normalized.
    return dragVector.
}

local function kate_trajectoryAcceleratioFunctionBodyCentric {
    parameter pShip, pShipArea, pBody, t, pos, vel.

    local atmAtParams is kate_AtmosphereAt(pos:mag - pBody:radius, vel:mag, pShipArea, pBody).
    local atmAccel is kate_atmosphericForceVector(vel, atmAtParams, pShipArea) / (ship:mass * 1E3).
    local gravity is -pBody:mu / (pos:mag^3) * pos.
    return gravity + atmAccel.
}


// Stops when the atmosphere has been exited or on crash
// Result is lexicon:  lexicon("result", result, "position", u:pos, "velocity", u:veleturn).
//   result  : completed | crashed | undefined
//   position: Vec
//   velocity: Vec
global function kate_simulateAtmosphericTrajectoryBodyCentricRK4 {
    parameter   pStartPosition, 
                pStartVelocity, 
                pStartTime,
                deltaTime is 1,
                pShipArea is 10,
                pShip is ship,
                pBody is body,
                maxSteps is 500. 

    local finished is false.
    local result is "undefined".

    local t_k is pStartTime.
    local stepAltitude is 0.
    local stepCount is 0.
    local qMax is 0.
    local altitudeMin is 1E20.
    local wallTempMax is 0.
    local h is deltaTime.
    local h_2 is h / 2. 
    local one_sixth_h is 1 / 6 * h. 

    local pos_k is pStartPosition - pBody:position.
    local vel_k is pStartVelocity - pBody:velocity:orbit.

    local accelerationFunction is kate_trajectoryAcceleratioFunctionBodyCentric@:bind(pShip, pShipArea, Body).

    until finished {
        local k1_pos is pos_k.
        local k1_vel is vel_k.
        local k1_acc is accelerationFunction(t_k, k1_pos, vel_k).

        local k2_pos is pos_k + h_2*k1_vel.
        local k2_vel is vel_k + h_2*k1_acc.
        local k2_acc is accelerationFunction(t_k, k2_pos, k2_vel).

        local k3_pos is pos_k + h_2*k2_vel.
        local k3_vel is vel_k + h_2*k2_acc.
        local k3_acc is accelerationFunction(t_k, k3_pos, k3_vel).

        local k4_pos is pos_k + h*k3_vel.
        local k4_vel is vel_k + h*k3_acc.
        local k4_acc is accelerationFunction(t_k, k4_pos, k4_vel).

        set pos_k to pos_k + one_sixth_h * (k2_vel + 2*(k2_vel + k3_vel) + k4_vel).
        set vel_k to vel_k + one_sixth_h * (k2_acc + 2*(k2_acc + k3_acc) + k4_acc).
        set t_k to t_k + h.
        
        // Get loads at end of step
        set stepAltitude to pos_k:mag - pBody:radius.

        local atmAtParams is kate_AtmosphereAt(stepAltitude, vel_k:mag, pShipArea).
        set qMax to max(qMax, atmAtParams:dynamicPressure).
        set wallTempMax to max(wallTempMax, atmAtParams:wallTemperature).
        
        // Left atmosphere again?
        set altitudeMin to min(altitudeMin, stepAltitude).
        if stepCount > maxSteps {
            set result to "undefined".
            set finished to true.
        } else if stepAltitude > pBody:atm:height {
            set result to "completed".
            set finished to true. 
        } else if stepAltitude < 2000 {
            set result to "crashed".
            set finished to true.
        }
        set stepCount to stepCount + 1.
    }

    return lexicon( "result",       result, 
                    "position",     pos_k + pBody:position + pBody:velocity:orbit * t_k, 
                    "velocity",     vel_k + pBody:velocity:orbit, 
                    "time",         t_k, 
                    "qMax",         qMax, 
                    "wallTempMax",  wallTempMax, 
                    "altitudeMin",  altitudeMin, 
                    "steps",        stepCount).
}

// Stops when the atmosphere has been exited or on crash
// Result is lexicon:  lexicon("result", result, "position", u:pos, "velocity", u:veleturn).
//   result  : completed | crashed | undefined
//   position: Vec
//   velocity: Vec
global function kate_simulateAtmosphericTrajectoryBodyCentricVelocityVerlet {
    parameter   pStartPosition, 
                pStartVelocity, 
                pStartTime,
                deltaTime is 1,
                pShipArea is 10,
                pShip is ship,
                pBody is body,
                maxSteps is 500. 

    local finished is false.
    local result is "undefined".

    local t_k is pStartTime.
    local stepAltitude is 0.
    local stepCount is 0.
    local qMax is 0.
    local altitudeMin is 1E20.
    local wallTempMax is 0.
    local h is deltaTime.
    local h_2 is h / 2.
    local h_square is h^2.
    local h_square_2 is (h^2)/2. 

    local accelerationFunction is kate_trajectoryAcceleratioFunctionBodyCentric@:bind(pShip, pShipArea, Body).
    
    local pos_k is pStartPosition - pBody:position.
    local vel_k is pStartVelocity - pBody:velocity:orbit.
    local acc_k is accelerationFunction(t_k, pos_k, vel_k).
    local vel_k_1_2 is vel_k + h_2 * acc_k.

    until finished {
        // Integrate
        local pos_k_1 is pos_k + h * vel_k_1_2.
        local acc_k_1 is accelerationFunction(t_k+ h, pos_k_1, vel_k).
        local vel_k_3_2 is vel_k_1_2 + h * acc_k_1.

        // Update
        set pos_k to pos_k_1.
        set vel_k_1_2 to vel_k_3_2.
        set t_k to t_k + h.
        
        // Get loads at end of step
        set stepAltitude to pos_k:mag - pBody:radius.
        // Arbitrary choice: use v(t+1/2t) here
        local atmAtParams is kate_AtmosphereAt(stepAltitude, vel_k_1_2:mag, pShipArea).
        set qMax to max(qMax, atmAtParams:dynamicPressure).
        set wallTempMax to max(wallTempMax, atmAtParams:wallTemperature).
        
        // Left atmosphere again?
        set altitudeMin to min(altitudeMin, stepAltitude).
        if stepCount > maxSteps {
            set result to "undefined".
            set finished to true.
        } else if stepAltitude > pBody:atm:height {
            set result to "completed".
            set finished to true. 
        } else if stepAltitude < 2000 {
            set result to "crashed".
            set finished to true.
        }
        set stepCount to stepCount + 1.
    }

    return lexicon( "result",       result, 
                    "position",     pos_k + pBody:position + pBody:velocity:orbit * t_k, 
                    "velocity",     vel_k + pBody:velocity:orbit, 
                    "time",         t_k, 
                    "qMax",         qMax, 
                    "wallTempMax",  wallTempMax, 
                    "altitudeMin",  altitudeMin, 
                    "steps",        stepCount).
}