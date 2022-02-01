@lazyGlobal off.

include("kate/core/kate_object").

global function KateConfig {
    local this is KateObject("KateConfig", "Config").

    set this:cpu to lexicon().

    this:def("initialize", KateConfig_initialize@).
    this:def("initializeExternals", KateConfig_initializeExternals@).
    this:def("copyExternal", KateConfig_copyExternal@).

    return this.
}


local function KateConfig_initialize {
    parameter   this.

    // Set default parameters
    set this:cpu:ui to true.
    set this:cpu:worker to true.
    set this:cpu:ipu to 500.
    set this:cpu:powerup to true.
    set this:cpu:sasControl to false.
    set this:cpu:modules to list("AUTOPLT","FLTAERO","NAVIGTN","SHIPSYS").

    local cpus is readJson("/kate/config/kate-cpus.json").
    local targetCpu is this:cpu.
    for cpuKey in cpus:keys {
        if cpuKey = core:tag and cpus:istype("Lexicon") {
            print "   Configure Cpu '" + cpuKey + "'".
            local selectedCpu is cpus[cpuKey].
            for key in selectedCpu:keys {
                set targetCpu[key] to selectedCpu[key].
            }
        }
    }
}

local function KateConfig_initializeExternals {
    parameter   this.

    local cpu is this:cpu.
    if cpu:hasKey("externals") {
        local externals is cpu:externals.
        for external in externals:keys {
            this:copyExternal(external, externals[external]).
        }
    }
}

local function KateConfig_copyExternal {
    parameter   this,
                localPath,
                remotePath.

    print "    Config - Install External '" + remotePath + "' to '" + localPath + "'".
    copyPath(remotePath, localPath).
}