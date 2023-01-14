@lazyGlobal off.

include("kate/core/kate_object").
include("kate/config/kate_config").
include("kate/messages/kate_messagequeue").
include("kate/runtime/kate_task_process").
include("kate/runtime/kate_remote_process").
include("kate/runtime/kate_warp_assist").
include("kate/ui/kate_ui").
include("kate/shell/kate_shell").

local PROCESS_COOLOFF_TIME_UI is TimeSpan(10).
local PROCESS_COOLOFF_TIME_WORKER is TimeSpan(0).
local MAX_MESSAGE_AGE is TimeSpan(10).

global function KateRuntime {
    local this is KateObject("KateRuntime", "KATE").

    set this:moduleCreators to list(). // which is sorted by module keys.
    set this:moduleIds to list(). // which is sorted by module keys.
    set this:modules to lexicon().
    set this:processes to list().

    set this:config to KateConfig().
    set this:messageQueue to KateMessageQueue().
    set this:ui to KateUi(this).
    set this:stopped to false.
    set this:processCooloffTime to PROCESS_COOLOFF_TIME_WORKER.
    set this:runsUi to false.
    set this:shell to KateShell(this).
    set this:warpAssist to KateWarpAssist(this).

    this:def("main", KateRuntime_main@).
    this:def("quit", KateRuntime_quit@).

    this:def("registerModule", KateRuntime_registerModule@).
    this:def("createModules", KateRuntime_createModules@).
    this:def("addModule", KateRuntime_addModule@).
    this:def("processMessages", KateRuntime_processMessages@).
    this:def("handleRuntimeMessage", KateRuntime_handleRuntimeMessage@).
    this:def("deferMessageToModule", KateRuntime_deferMessageToModule@).

    this:def("startTask", KateRuntime_startTask@). // returns KateTaskProcess
    this:def("abortProcesses", KateRuntime_abortProcesses@). 
    this:def("runProcesses", KateRuntime_runProcesses@).
    this:def("activeProcesses", KateRuntime_activeProcesses@).
    this:def("runModules", KateRuntime_runProcesses@).
    this:def("processesForTask", KateRuntime_processesForTask@).
    this:def("requestStandby", KateRuntime_requestStandby@).

    this:def("mirrorProcessToUi", KateRuntime_mirrorProcessToUi@).
    this:def("getProcessWithPid", KateRuntime_getProcessWithPid@).

    this:def("sendMessage", KateRuntime_sendMessage@).
    this:def("log", KateRuntime_log@).
    
    return this.
}

local function KateRuntime_main {
    parameter this.

    print "Initializing Core...".
    this:config:initialize().
    set config:ipu to getOrDefault(this:config:cpu, "ipu", 500).
    set this:runsUi to getOrDefault(this:config:cpu, "ui", true).
    set this:processCooloffTime to choose PROCESS_COOLOFF_TIME_UI if this:runsUi else PROCESS_COOLOFF_TIME_WORKER.

    print "Initializing modules...".
    this:createModules().
    this:log("KATE running...").

    print "Starting main loop...".
    until this:stopped {
        this:messageQueue:update().
        this:processMessages().
        this:runProcesses().
        if this:runsUi {
            this:ui:safeCall1("update", this).
            this:ui:safeCall1("react", this).
        }
        this:messageQueue:clearAgedOver(MAX_MESSAGE_AGE).
        this:messageQueue:clearAcknowledged().

        local waitTime is choose 0.01 if this:processes:length > 0 else 0.1.
        wait waitTime.
    }
}

local function KateRuntime_quit {
    parameter this.

    set this:stopped to true.
}

local function KateRuntime_registerModule {
    parameter this,
              moduleCreator.

    this:moduleCreators:add(moduleCreator).
}

local function KateRuntime_createModules {
    parameter this.

    local configuredModules is this:config:cpu:modules.
    for moduleCreator in this:moduleCreators {
        local module is moduleCreator:call().
        if configuredModules:find(module:id) > -1 {
            this:addModule(module).
        }
    }
}

local function KateRuntime_addModule {
    parameter this,
              module.

    local id is module:id.
    print "  Adding module: " + id.

    this:moduleIds:add(id).
    this:modules:add(id, module).
}

local function KateRuntime_startTask {
    parameter this,
              module,
              task.

    local taskProcess is KateTaskProcess(module, task, this).
    this:processes:add(taskProcess).

    this:ui:safeCall2("addProcess", taskProcess, task:uiContentHeight).
    this:log("Started process " + taskProcess:id).

    return taskProcess.
}

local function KateRuntime_runProcesses {
    parameter this.

    local cleanupProcesses is list().

    for process in this:processes {
        process:safeCall0("work").
        if process:finished {
            if process:lastExecTime + this:processCooloffTime < time {
                this:log("Finished process " + process:id).
                cleanupProcesses:add(process).
            }
        }
        // Mirror local processes from non-ui to ui node
        if not ((this:config):cpu):ui and process:local {
            this:mirrorProcessToUi(process).
        }
    }

    for process in cleanupProcesses {
        local index is this:processes:find(process).
        if index >= 0 {
            this:processes:remove(index).
            this:ui:safeCall1("removeProcess", process).
        }
    }

    this:warpAssist:safeCall0("updateWarpPoints").
}

local function KateRuntime_activeProcesses {
    parameter this.

    local activeProcesses is list().
    for process in this:processes {
        if not process:finished {
           activeProcesses:add(process).
        }
    }
    return activeProcesses.
}

local function KateRuntime_abortProcesses {
    parameter this.

    this:log("Halting all active processes").

    for process in this:processes {
        process:safeCall0("stop").
        this:ui:safeCall1("removeProcess", process).
    }
    
    this:processes:clear().
}

local function KateRuntime_processesForTask {
    parameter this,
              taskId.

    local result is list().
    for process in this:processes {
        if process:isClass("KateTaskProcess") and process:task:id = taskId {
            result:add(process).
        }
    }
    return result.
}

local function KateRuntime_mirrorProcessToUi {
    parameter this,
              process.

    local uiTitleBuffer is process:safeCall0("uiTitle").
    local uiLineBuffer is process:safeCall0("uiContent").
    local processUpdateMessage is lexicon().

    set processUpdateMessage:pid to process:id + "@" + core:tag.
    set processUpdateMessage:uiTitleBuffer to uiTitleBuffer.
    set processUpdateMessage:uiLineBuffer to uiLineBuffer.
    set processUpdateMessage:finished to process:finished.

    local message is lexicon().
    set message["processUpdate"] to processUpdateMessage.

    // For now we do not know, which core runs the ui, so we send it to "*".
    this:sendMessage("Runtime", ship:name, "*", "Runtime", message).
}

local function KateRuntime_processMessages {
    parameter this.

    local messages is this:messageQueue:all().
    for message in messages {
        local receiverModules is list().

        if message:targetVessel = "*" or message:targetVessel = ship:name {
            local targetModule is message:targetModule.
            if targetModule = "Runtime" {
                this:handleRuntimeMessage(message).
            } else {
                for module in this:modules:values {
                    if targetModule = "*" or targetModule = module:id {
                        receiverModules:add(module).
                    }
                }
            }
        }

        for module in receiverModules {
            this:deferMessageToModule(module, message).
        }
        message:acknowledge().
    }
}

local function KateRuntime_handleRuntimeMessage {
    parameter this,
              message.

    local messageContent is message:content.

    if messageContent:hasKey("processUpdate") {
        local processUpdateMessage is messageContent["processUpdate"].
        local pid is processUpdateMessage:pid.
        local process is this:getProcessWithPid(pid).
        if process <> 0 and process:class = "KateRemoteProcess" {
            process:handleUpdateMessage(processUpdateMessage).
        } else {
            local newProcess is KateRemoteProcess_fromMessage(processUpdateMessage, pid).
            (this:processes):add(newProcess).
            local uiContentSize is (newProcess:uiLineBuffer):length.
            this:ui:safeCall2("addProcess", newProcess, uiContentSize).
        }
    }
    message:acknowledge().
}

local function KateRuntime_getProcessWithPid {
    parameter this,
              pid.

    for process in this:processes {
        if process:id = pid return process.
    }
    return 0.
}

local function KateRuntime_deferMessageToModule {
    parameter this,
              module,
              message.

    module:safeCall2("handleMessage", this, message).
}

local function KateRuntime_sendMessage {
    parameter this,
              pSenderModule is "?",
              pTargetVessel is "*",
              pTargetCore is "*",
              pTargetModule is "*",
              messageContent is lexicon().
    
    this:messageQueue:createAndSendMessage(pSenderModule, pTargetVessel, pTargetCore, pTargetModule, messageContent).
}

local function KateRuntime_log {
    parameter this,
              text.
               
    if not ((this:config):cpu):ui {
        print time:full + " - " + text.
    } else {
        //this:ui:safeCall1("setStatus", text).
        this:shell:safeCall1("println", text).
    }
}

local function KateRuntime_requestStandby {
    parameter this,
              standbyOn. // boolean
    
    if standbyOn {
        set config:ipu to 50.
    } else {
        set config:ipu to getOrDefault(this:config:cpu, "ipu", 500).
    }
}

global KATE is KateRuntime().
