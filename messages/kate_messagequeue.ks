@lazyGlobal off.

include("kate/core/kate_object").
include("kate/messages/kate_message").
include("kate/library/lib_enum").

global function KateMessageQueue {
    local this is KateObject("KateMessageQueue", "MQ").

    set this:shipQueue to ship:messages.
    set this:coreQueue to core:messages.
    set this:internal to list().
    
    this:def("all", KateMessageQueue_all@).
    this:def("allWhich", KateMessageQueue_allWhich@).
    this:def("allOfType", KateMessageQueue_allOfType@).
    this:def("isEmpty", KateMessageQueue_isEmpty@).
    this:def("receiveFrom", KateMessageQueue_receiveFrom@).
    this:def("clearAcknowledged", KateMessageQueue_clearAcknowledged@).
    this:def("clearAgedOver", KateMessageQueue_clearAgedOver@).
    this:def("update", KateMessageQueue_update@).
    this:def("messageCount", KateMessageQueue_messageCount@).
    this:def("createAndSendMessage", KateMessageQueue_createAndSendMessage@).
    this:def("send", KateMessageQueue_send@).
    this:def("activeLocalProcessors", KateMessageQueue_activeLocalProcessors@).

    return this.
}

local function KateMessageQueue_all {
    parameter   this.
    
    return this:internal.
}

local function KateMessageQueue_allWhich {
    parameter   this,
                condition.
    
    return Enum:select(this:internal, condition).
}

local function KateMessageQueue_allOfType {
    parameter   this,
                msgType.
    
    Enum:select(this:internal, {parameter x. return x:kateMsgKind = msgType.}).
}

local function KateMessageQueue_isEmpty {
    parameter   this.

    return this:internal:length = 0.
}

local function KateMessageQueue_messageCount {
    parameter   this.
    
    return this:internal:length.
}

local function KateMessageQueue_receiveFrom {
    parameter   this,
                kosQueue.
    
    if not kosQueue:empty {
        local kosMessage is kosQueue:pop().
        local messageContent is kosMessage:content.
        if messageContent:istype("Lexicon") and messageContent:haskey("class") and messageContent["class"] = "KateMessage" {
            local kateMessage is KateMessageOfKosMessage(kosMessage).
            this:internal:add(kateMessage).
        } else {
            KATE:safeCall1("setMessage", "Unknown message type received").
        }
    }
}

local function KateMessageQueue_clearAcknowledged {
    parameter   this.
    
    local filteredMessages is Enum:select(this:internal, {parameter x. return x:status <> KATE_MSG_ACKNOWLEDGED.}).
    set this:internal to filteredMessages.
}

local function KateMessageQueue_clearAgedOver {
    parameter   this,
                maxTimeSpan.
    
    local filteredMessages is Enum:select(this:internal, {parameter x. return x:age() > maxTimeSpan.}).
    set this:internal to filteredMessages.
}

local function KateMessageQueue_update {
    parameter   this.
    
    this:receiveFrom(this:shipQueue).
    this:receiveFrom(this:coreQueue).
}

local function KateMessageQueue_createAndSendMessage {
    parameter this,
              pSenderModule is "?",
              pTargetVessel is "*",
              pTargetCore is "*",
              pTargetModule is "*",
              messageContent is lexicon().

    local msg is KateMessage().
    set msg:status to "INIT".
    set msg:senderVessel to ship:name.
    set msg:senderCore to core:tag.
    set msg:senderModule to pSenderModule.
    set msg:targetVessel to pTargetVessel. 
    set msg:targetCore to pTargetCore. 
    set msg:targetModule to pTargetModule.
    set msg:content to messageContent.
    
    this:send(msg).
}

local function KateMessageQueue_send {
    parameter   this,
                message.
    
    if message:targetVessel = ship:name {
        if message:targetCore = core:tag {
            // Message to own core
            core:connection:sendMessage(message:toKosMessage()).
        } else {
            for proc in this:activeLocalProcessors() {
                // Message to other cores
                if message:targetCore = "*" or message:targetCore = proc:tag {
                    proc:connection:sendMessage(message:toKosMessage()).
                }
            }
        }
    } else {
        // Send to other vessels
        local targetVessels is list().
        local allVessels is list().
        list targets in allVessels.

        if message:targetVessel = "*" {
            for vsl in allVessels {
                if vsl:name <> ship:name {
                    targetVessels:add(vsl).
                }
            }
        } else {
            for vsl in allVessels {
                if vsl:name = message:targetVessel {
                    targetVessels:add(vsl).
                }
            }
        }
        for tgt in targetVessels {
            tgt:connection:sendMessage(message:toKosMessage()).
        }
    }
}

local function KateMessageQueue_activeLocalProcessors {
    parameter   this.

    local result is list().
    local allProcessors is list().

    list PROCESSORS in allProcessors.
    for proc in allProcessors {
        if proc:mode = "READY" and proc:tag <> core:tag {
            result:add(proc).
        }
    }
    return result.
}