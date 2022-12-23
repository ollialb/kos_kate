@lazyGlobal off.

global function KateCompiler {
    local this is lexicon().

    clearscreen.

    set this:compileTree to KateCompiler_compileTree@:bind(this).
    set this:compileVolumeDirectory to KateCompiler_compileVolumeDirectory@:bind(this).
    
    return this.
}

local function KateCompiler_compileTree {
    parameter this,
              sourceVolumeId,
              sourceDirName,
              targetVolumeId,
              targetDirName.

    local error is false.
    local sourcePath is sourceVolumeId + ":" + sourceDirName.
    local targetPath is targetVolumeId + ":" + targetDirName + "/" + sourceDirName.
    local targetVolume is volume(targetVolumeId).

    print "KATE Compiler ---------------------------------- ".
    print "Cleaning target '" + targetPath + "'" at (0, 2).
    if exists(targetPath) {
        deletePath(targetPath).
    }
    if exists(sourcePath) {
        print "Compiling from '" + sourcePath + "' to '" + targetPath + "'" at (0, 2).
        local sourceDir is open(sourcePath).
        if sourceDir:istype("VolumeDirectory") {
            set error to this:compileVolumeDirectory(sourcePath, sourceDir, targetVolume, targetPath) or error.
        }
    } else {
        print "ERROR: Cannot access '" + sourcePath + "'" at (0, 30).
        print 1/0.
    }

    return not error.
}

local function KateCompiler_compileVolumeDirectory {
    parameter this,
              sourceDirPath,
              sourceDir,
              targetVolume,
              targetDirPath.

    local error is false.
    local safetyMargin is 1000. // bytes

    if sourceDir:istype("VolumeDirectory") {
        createDir(targetDirPath).
        local filesInSourceDir is sourceDir:lexicon.
        for fileInSourceDir in filesInSourceDir:values {
            local fileName is fileInSourceDir:name.
            local isSourceFile is fileInSourceDir:isfile and fileInSourceDir:extension = "ks".
            local isDirectory is fileInSourceDir:istype("VolumeDirectory").
            local isHidden is fileName:startsWith(".").
            local fileTruncName is (fileName:split("."))[0].
            local sourceFileName is sourceDirPath + "/" + fileName.
            local targetFileName is targetDirPath + "/" + fileTruncName + ".ksm".
            if isSourceFile {
                local neededSize is fileInSourceDir:size.
                if neededSize + safetyMargin > targetVolume:freeSpace {
                    print "ERROR: Not enough space on target volume (" + targetVolume:freeSpace + " bytes)!         " at (0, 4).
                    return false.
                }
                print "Compiling: " + fileName + "                 " at (0, 4).
                compile sourceFileName to targetFileName.
            } else if isDirectory and not isHidden {
                print "Directory: " + fileName + "                 " at (0, 3).
                set error to this:compileVolumeDirectory(sourceFileName, fileInSourceDir, targetVolume, targetDirPath + "/" + fileName) or error.
            }
        }
    } else {
        print "ERROR: " + sourceDirPath + " is not a directory!" at (0, 30).
        print 1/0.
    }

    return not error.
}
