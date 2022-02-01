@lazyGlobal off.

global function KateLoader {
    local this is lexicon().

    clearscreen.

    set this:loadModules to KateLoader_loadModules@:bind(this).
    set this:loadModulesFromVolumeDirectory to KateLoader_loadModulesFromVolumeDirectory@:bind(this).
    
    return this.
}

local function KateLoader_loadModules {
    parameter this,
              scanDir.

    print "KATE Loader ---------------------------------- ".
    if exists(scanDir) {
        print "Scanning for modules in '" + scanDir + "'" at (0, 2).
        local moduleDir is open(scanDir).
        if moduleDir:istype("VolumeDirectory") {
            this:loadModulesFromVolumeDirectory(scanDir, moduleDir).
        }
    }  else {
        print "ERROR: Cannot access '" + scanDir + "'" at (0, 30).
    }
}

local function KateLoader_loadModulesFromVolumeDirectory {
    parameter this,
              moduleDirPath,
              moduleDir.

    if moduleDir:istype("VolumeDirectory") {
        local filesInModuleDir is moduleDir:lexicon.
        for fileInModuleDir in filesInModuleDir:values {
            local fileName is fileInModuleDir:name.
            local filePath is moduleDirPath + "/" + fileName.
            if fileInModuleDir:isfile {
                print "Loading: " + fileName + "                 " at (0, 4).
                include(filePath).
            } else {
                print "Scanning: " + fileName + "                 " at (0, 3).
                this:loadModulesFromVolumeDirectory(filePath, fileInModuleDir).
            }
        }
    } else {
        print "ERROR: " + moduleDir:moduleDirPath + " is not a directory!" at (0, 30).
        print 1/0.
    }
}
