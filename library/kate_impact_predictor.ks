@lazyGlobal off.

include ("kate/core/kate_object").

global function KateImpactPredictor {
    local this is KateObject("KateImpactPredictor", ship:name).

    set this:impactPositionAveraged to KateAveragedValue("impactPosition", 10, V(0,0,0)).
    set this:impactTimeAveraged to KateAveragedValue("impactTime", 10, 0).

    // Returns the impact position in ship coordinates
    this:def("hasImpact", KateImpactPredictor_hasImpact@).
    this:def("averagedEstimatedImpactPosition", KateImpactPredictor_averagedEstimatedImpactPosition@).
    this:def("estimatedImpactPosition", KateImpactPredictor_estimatedImpactPosition@).
    this:def("estimatedImpactPositionWithTrajectories", KateImpactPredictor_estimatedImpactPositionWithTrajectories@).
    this:def("estimatedImpactPositionWithIntervalSearch", KateImpactPredictor_estimatedImpactPositionWithIntervalSearch@).
    this:def("estimatedImpactPositionWithNewtonIntervals", KateImpactPredictor_estimatedImpactPositionWithNewtonIntervals@).
    this:def("altitudeOfPosition", KateImpactPredictor_altitudeOfPosition@).
    
    return this.
}

local function KateImpactPredictor_averagedEstimatedImpactPosition {
    parameter this.

    local lastImpactPositionResult is this:estimatedImpactPosition().
    local lastImpactPosition is lastImpactPositionResult:position.
    local lastImpactTime is lastImpactPositionResult:time.
    this:impactPositionAveraged:setLastValue(lastImpactPosition).
    this:impactTimeAveraged:setLastValue(lastImpactTime).
    return lexicon("position", this:impactPositionAveraged:averageValue(), "time", TimeSpan(this:impactTimeAveraged:averageValue())).
}

local function KateImpactPredictor_hasImpact {
    parameter   this.
    
    if addons:tr:available and addons:tr:isVerTwoTwo {
        return addons:tr:hasImpact.
    } else {
       local minRadius is ship:body:radius + 2000.
       return ship:orbit:periapsis > minRadius and ship:orbit:apoapsis > minRadius.
    }
}

local function KateImpactPredictor_estimatedImpactPosition {
    parameter   this.
    
    if addons:tr:available and addons:tr:isVerTwoTwo {
        return this:estimatedImpactPositionWithTrajectories().
    } else {
        return this:estimatedImpactPositionWithNewtonIntervals().
    }
}

// Returns time and position where the ship's current orbit will intersect the terrain or sea level.
// If no such point is found, the {0, V(0,0,0)} is returned.
local function KateImpactPredictor_estimatedImpactPositionWithIntervalSearch {
    parameter   this.

    local minRadius is ship:body:radius.
    if ship:orbit:periapsis > minRadius and ship:orbit:apoapsis > minRadius lexicon("time", 0, "position", V(0,0,0)).

    local etaAp is time:seconds + ship:orbit:eta:apoapsis.
    local etaPe is time:seconds + ship:orbit:eta:periapsis.
    local timeMin is time:seconds.
    local timeMax is choose etaAp if etaAp > etaPe else etaPe.
    local timeMid is timeMin + (timeMax - timeMin) * 0.5.
    local altitudeAtTimeMid is this:altitudeOfPosition(positionAt(ship, timeMid)).
    local altitudeAtTimeMax is this:altitudeOfPosition(positionAt(ship, timeMax)).
    local altitudeAtTimeMin is this:altitudeOfPosition(positionAt(ship, timeMin)).
    local iteration is 0.

    // 10 m accuracy is enough
    until abs(altitudeAtTimeMid) < 10 {
        set iteration to iteration + 1.
        local dAltitude is (altitudeAtTimeMax - altitudeAtTimeMin).
        local dTime is (timeMax - timeMin).
        // Abort if the interval gets too small without a solution
        if abs(dTime) < 1 or abs(dAltitude) < 100 {
            return lexicon("time", timeMid, "position", positionAt(ship, timeMid)).
        }
        if altitudeAtTimeMid > 0 {
            set timeMin to timeMid.
            set timeMid to timeMin + (timeMax - timeMin) * 0.5.
            set altitudeAtTimeMin to altitudeAtTimeMid.
            set altitudeAtTimeMid to this:altitudeOfPosition(positionAt(ship, timeMid)).
        } else if altitudeAtTimeMid < 0 {
            set timeMax to timeMid.
            set timeMid to timeMin + (timeMax - timeMin) * 0.5.
            set altitudeAtTimeMax to altitudeAtTimeMid.
            set altitudeAtTimeMid to this:altitudeOfPosition(positionAt(ship, timeMid)).
        }
        print iteration at (10, 34).
        print timeMid - time:seconds at (10, 35).
        print altitudeAtTimeMid at (10, 36).
    }
    return lexicon("time", timeMid, "position", positionAt(ship, timeMid)).
}

local function KateImpactPredictor_estimatedImpactPositionWithNewtonIntervals {
    parameter   this.

    local minRadius is ship:body:radius.
    if ship:orbit:periapsis > minRadius and ship:orbit:apoapsis > minRadius lexicon("time", 0, "position", V(0,0,0)).

    local etaAp is time:seconds + ship:orbit:eta:apoapsis.
    local etaPe is time:seconds + ship:orbit:eta:periapsis.
    local timeMin is time:seconds.
    local timeMax is choose etaAp if etaAp > etaPe else etaPe.
    local timeVal is timeMin + (timeMax - timeMin) * 0.5.
    local altitudeAtTimeVal is ship:body:altitudeof(positionAt(ship, timeVal)).
    local iteration is 0.

    // 10 m accuracy is enough
    until abs(altitudeAtTimeVal) < 10 or iteration > 10 {
        set iteration to iteration + 1.
        local dAdT is velocityAt(ship, timeVal):surface:z.
        set timeVal to timeVal - altitudeAtTimeVal / dAdT.
        print iteration at (10, 34).
        print dAdT at (30, 34).
        print timeVal - time:seconds at (10, 35).
        print altitudeAtTimeVal at (10, 36).
    }
    return lexicon("time", timeVal, "position", positionAt(ship, timeVal)).
}

local function KateImpactPredictor_estimatedImpactPositionWithTrajectories {
    parameter   this.

    if addons:tr:hasImpact {
        return lexicon("time", time:seconds + addons:tr:timeTillImpact, "position", addons:tr:impactPos:position).
    } else {
        return lexicon("time", 0, "position", V(0,0,0)).
    }
}

local function KateImpactPredictor_altitudeOfPosition {
    parameter   this,
                positionInShipCoordinates.

    local positionLatLng is ship:body:geopositionof(positionInShipCoordinates).
    local altitudeOfPosition is ship:body:altitudeof(positionInShipCoordinates).
    local terrainHeight is positionLatLng:terrainheight.
    if (terrainHeight < 0) {
        return ship:body:radius.
    } else {
        return altitudeOfPosition - terrainHeight.
    }
}