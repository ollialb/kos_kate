@lazyGlobal OFF.

print "Booting KATE environment...".
wait until ship:unpacked.

print "  Configuring KOS and CPU".
set config:safe to true.
set config:ucp to true.

if core:tag = "disabled" {
    print "  CPU is disabled. STOP.".
} else {
    local oldipu is config:ipu.
    set config:ipu to 2000.

    print "  Checking for connection to archive...".
    local archiveOnline is core:connection:isconnected.
    if archiveOnline {
        print "      Archive is online.".
        print "      Compile and install KATE library".
        runOncePath("0:/kate/runtime/kate_compiler").
        local compiler is KateCompiler().
        local compiledOk is compiler:compileTree(0, "kate", 1, "").
        if compiledOk {
            print "      Compiled KATE to local volume".
            copypath("0:/kate/config/kate-cpus.json", "1:/kate/config/kate-cpus.json").
            switch to 1.
        } else {
            print "      Could not compile KATE to local volume".
            switch to "archive".
        }
    } else {
        print "  Archive is offline - try to boot from local.".
        switch to 1.
    }

    print "  Loading KATE runtime".
    runOncePath("kate/runtime/kate_fileio").
    runOncePath("kate/runtime/kate_runtime").
    runOncePath("kate/runtime/kate_loader").

    print "  Loading KATE modules".
    local loader is KateLoader().
    loader:loadModules("kate/core_modules").
    loader:loadModules("kate/user_modules").

    set config:ipu to oldipu.
    print "  Starting KATE runtime".
    KATE:main().
}

clearScreen.
print "KATE Terminated.".
switch to 1.