@lazyGlobal OFF.

function include {
    parameter pProgramName.

    local programFile is pProgramName.
    if exists(programFile) {
        runOncePath(programFile).
    } else {
        print "ERROR: Can't find dependency: " + programFile at (0, 30).
        print 1/0.
    }
}

