@lazyGlobal OFF.

print "Booting KATE environment...".
wait until ship:unpacked.

print "  Configuring CPU".
set config:safe to true.
if core:tag = "disabled" {
    print "CPU is disabled".
} else {
    set config:ipu to 2000.

    print "  Setting volumes up".
    local coreTag is core:tag.
    local localVolumeName is choose "local" if coreTag:length=0 else coreTag.
    set core:volume:name to localVolumeName.

    print "  Installing KATE library".
    switch to localVolumeName.
    if (exists("kate")) {
        deletePath("kate").
    }

    createDir("kate").
    copypath("archive:/kate/messages", "kate").
    copypath("archive:/kate/modules", "kate").
    copypath("archive:/kate/runtime", "kate").
    copypath("archive:/kate/config", "kate").
    copypath("archive:/kate/core", "kate").
    copypath("archive:/kate/core_modules", "kate").
    copypath("archive:/kate/ui", "kate").
    copypath("archive:/kate/library", "kate").
    copypath("archive:/kate/data", "kate").

    print "  Loading KATE configuration".
    copypath("archive:/kate-cpus.json", "kate/config").

    print "  Loading KATE runtime".
    runOncePath("kate/runtime/kate_fileio.ks").
    runOncePath("kate/runtime/kate_runtime.ks").
    runOncePath("kate/runtime/kate_loader.ks").

    print "  Loading KATE modules".
    local KATELOAD is KateLoader().
    KATELOAD:loadModules("kate/core_modules").
    KATELOAD:loadModules("kate/user_modules").

    print "  Starting KATE runtime".
    KATE:main().
}

clearScreen.
print "KATE Terminated.".