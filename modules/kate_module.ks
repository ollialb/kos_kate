@lazyGlobal off.

include("kate/core/kate_object").
include("kate/modules/kate_task_parameter_dialog").

// drawUi (offX, offY)
global function KateModule {
    parameter moduleClass, moduleId.
    local this is KateObject(moduleClass, moduleId).

    set this:activeTasks to 0.
    set this:tasks to uniqueSet().
    set this:taskCreators to lexicon().
    set this:taskParameterDialog to 0.

    this:def("runAsyncTask", KateModule_runAsyncTask@).
    this:def("handleMessage", KateModule_handleMessage@).
    this:def("createTask", KateModule_createTask@).
    this:def("createAndStartTask", KateModule_createAndStartTask@). // returns: void.
    this:def("createAndStartTaskWithParameterInput", KateModule_createAndStartTaskWithParameterInput@). // returns: void.
    
    this:def("startTaskParameterDialog", KateModule_startTaskParameterDialog@). // returns: void.
    this:def("finishTaskParameterDialog", KateModule_finishTaskParameterDialog@). // returns: void.
    this:def("abortTaskParameterDialog", KateModule_abortTaskParameterDialog@). // returns: void.

    this:def("uiContent", KateModule_uiContent@). // returns: list of strings.
    this:def("handleUiInput", KateModule_handleUiInput@). // returns: void.

    this:abstract("updateState"). // returns: void.
    this:abstract("renderModuleUi"). // returns: list of strings.
    this:abstract("handleModuleInput"). // returns: void.

    return this.
}

local function KateModule_runAsyncTask {
    parameter   this,
                runtime,
                taskId,
                taskParams,
                targetVessel is ship:name,
                targetCore is core:tag,
                targetModule is this:id.


    local message is lexicon().
    set message:taskId to taskId.
    set message:taskParams to taskParams.

    runtime:sendMessage(this:id, targetVessel, targetCore, targetModule, message).
}

local function KateModule_handleMessage {
    parameter   this,
                runtime,
                message.
                
    if message:haskey("content") {
        local msg is message:content.
        if msg:haskey("taskId") and msg:haskey("taskParams") {
            local moduleId is this:id.
            local taskId is msg:taskId.
            local taskParams is msg:taskParams.
            this:createAndStartTask(runtime, taskId, taskParams).
            message:acknowledge().
        }
    }
}

local function KateModule_createTask {
    parameter   this,
                taskId,
                taskParams.

    if (this:taskCreators:haskey(taskId)) {
        local creator is this:taskCreators[taskId].
        local newTask is creator:call().
        for paramId in taskParams:keys {
            newTask:setParameter(paramId, taskParams[paramId]).
        }
        return newTask.
    } else {
        print "UNKNOWN TASK " + taskId + " CALLED!!!" at (10, 30).
        return 0.
    }
}

local function KateModule_createAndStartTask {
    parameter   this,
                runtime,
                taskId,
                taskParams.

    local task is this:createTask(taskId, taskParams).
    if task <> 0 {
        runtime:safeCall2("startTask", this, task).
    }
    return task.
}

local function KateModule_createAndStartTaskWithParameterInput {
    parameter   this,
                runtime,
                taskId,
                taskParams.

    local task is this:createTask(taskId, taskParams).
    if task <> 0 {
        if task:parameterDeclarations:keys:empty {
            runtime:safeCall2("startTask", this, task).
        } else {
            this:startTaskParameterDialog(task).
        }
    }
    return task.
}

local function KateModule_uiContent {
    parameter   this.

    if this:taskParameterDialog <> 0 {
        return this:taskParameterDialog:safeCall0("uiContent").
    } else {
        this:updateState().
        return this:renderModuleUi().
    }
}

local function KateModule_handleUiInput {
    parameter   this,
                runtime,
                inputCharacter.

    if this:taskParameterDialog <> 0 {
        this:taskParameterDialog:safeCall2("handleUiInput", runtime, inputCharacter).
    } else {
        this:handleModuleInput(runtime, inputCharacter).
    }
}

local function KateModule_startTaskParameterDialog {
    parameter this,
              task.
    
    set this:taskParameterDialog to KateTaskParameterDialog(this, task).
}

local function KateModule_finishTaskParameterDialog {
    parameter this,
              runtime,
              task.

    if task <> 0 {
        runtime:safeCall2("startTask", this, task).
    }
    set this:taskParameterDialog to 0.
}

local function KateModule_abortTaskParameterDialog {
    parameter this,
              runtime,
              task.

    if task <> 0 {
        task:finish().
    }
    set this:taskParameterDialog to 0.
}