@lazyGlobal off.

global KATE_MSG_SENT is "SENT".
global KATE_MSG_RECEIVED is "RECV".
global KATE_MSG_ACKNOWLEDGED is "ACKN".

include ("kate/core/kate_object").

// Message is a lexicon, which can be transmitted in the KATE environment.
// :kind is always "KateMessage"
// :content contains the actual payload
// :sender contains the name of the sending vessel or "-",m if the sender could not be identified.
// :status contains the status if the message:
//         "SENT" - the initial status.
//         "RECV" - when the message has been received in a queue.
//         "ACKN" - when the message has been handled by a subscriber.
global function KateMessage {
    local this is KateObject("KateMessage", "Msg").

    set this:class to "KateMessage".
    set this:status to KATE_MSG_SENT.
    set this:senderVessel to "".
    set this:senderCore to "".
    set this:senderModule to "".
    set this:targetVessel to "*". // All vessels
    set this:targetCore to "*". // All cores
    set this:targetModule to "".
    set this:content to lexicon().
  
    this:def("fromKosMessage", KateMessage_fromKosMessage@).
    this:def("toKosMessage", KateMessage_toKosMessage@).
    this:def("age", KateMessage_age@).
    this:def("acknowledge", KateMessage_acknowledge@).

    return this.
}

global function KateMessageOfKosMessage {
    parameter this.

    local msg is KateMessage().
    msg:fromKosMessage(this).
    return msg.
}

local function KateMessage_fromKosMessage {
    parameter this,
              kosMessage.

    set this:status to KATE_MSG_RECEIVED.
    set this:sentat to kosMessage:sentat.
    set this:receivedat to kosMessage:receivedat.
    set this:senderVessel to kosMessage:content:senderVessel.
    set this:senderCore to kosMessage:content:senderCore.
    set this:senderModule to kosMessage:content:senderModule.
    set this:targetVessel to kosMessage:content:targetVessel.
    set this:targetCore to kosMessage:content:targetCore.
    set this:targetModule to kosMessage:content:targetModule.
    set this:content to kosMessage:content:content.

    return this.
}

// The KOS message must not include delegates, so we must copy the content into a new lexicon!
local function KateMessage_toKosMessage {
    parameter this.

    local result is lexicon().

    set result:class to this:class.
    set result:status to this:status.
    set result:senderVessel to this:senderVessel.
    set result:senderCore to this:senderCore.
    set result:senderModule to this:senderModule.
    set result:targetVessel to this:targetVessel.
    set result:targetCore to this:targetCore.
    set result:targetModule to this:targetModule.
    set result:content to this:content.

    return result.
}

local function KateMessage_age {
    parameter this.
    if this:hasKey("receivedat") {
        return time - this:receivedat.
    } else {
        return TimeSpan(0).
    }
}

local function KateMessage_acknowledge {
    parameter this.
    set this:status to KATE_MSG_ACKNOWLEDGED.
}
