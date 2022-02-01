@lazyGlobal off.

global function kate_normalTerrainVector {
    parameter pBody, 
              pPosition.

    local gridSize is 3.
    local upVector is (pPosition - pBody:position):normalized.
    local northVector is vectorExclude(upVector, latlng(90, 0):position - pPosition):normalized * gridSize.
    local eastVector is vectorCrossProduct(upVector, northVector):normalized * gridSize.

    local southEastPosition is pBody:geoPositionOf(pPosition - northVector + eastVector):position - pPosition.
    local southWestPosition is pBody:geoPositionOf(pPosition - northVector - eastVector):position - pPosition.
    local northPosition     is pBody:geoPositionOf(pPosition + northVector):position - pPosition. 

    return vectorCrossProduct((southEastPosition - northPosition), (southWestPosition - northPosition)):normalized.
}

global function kate_terrainSlope {
    parameter pBody, 
              pPosition.

    local terrainNormal is kate_normalTerrainVector(pBody, pPosition).
    local upVector is (pPosition - pBody:position):normalized.
    return vectorAngle(terrainNormal, upVector).
}

global function kate_downhillVector {
    parameter pBody, 
              pPosition.

    local terrainNormal is kate_normalTerrainVector(pBody, pPosition).
    local upVector is (pPosition - pBody:position):normalized.
    return vectorExclude(upVector, terrainNormal):normalized.
}
