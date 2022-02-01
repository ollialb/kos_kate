@lazyGlobal off.

include ("kate/core/kate_object").

global function KateMissionElement {
    parameter pName,
              pTaskId,
              pTaskParams.
    local this is KateObject("KateMissionElement", pName).

    set this:taskId to pTaskId.
    set this:taskParams to pTaskParams.

    return this.
}