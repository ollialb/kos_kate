@lazyGlobal off.

include("kate/core/kate_object").

local MINUSSES is "╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌".
local GRAYBAR  is "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░".
local SPACES  is  "                                                                                                                           ".

function KateWindow {
    parameter id, pleft, ptop, pwidth, pheight, ptitleProvider, pcontentProvider, pInputHandler is KateWindow_defaultInputHandler@.
    local this is KateObject("KateWindow", id).
    
    set this:top to ptop.
    set this:left to pleft.
    set this:width to pwidth.
    set this:height to pheight.
    set this:titleProvider to ptitleProvider.
    set this:contentProvider to pcontentProvider.
    set this:inputHandler to pInputHandler.

    this:def("drawFrame", KateWindow_drawFrame@).
    this:def("drawContent", KateWindow_drawContent@).
    this:def("handleInput", KateWindow_handleInput@).

    return this.
}

local function KateWindow_drawFrame {
    parameter this.

    local top is this:top.
    local left is this:left.
    local width is this:width.
    local height is this:height.

    local title is this:titleProvider:call(). // string

    local headerLine is "░" + GRAYBAR:substring(0, 1) + "░ █ " + title + " ░" + GRAYBAR:substring(0, width - 9 - title:length) + "░".
    local footerLine is "└" + MINUSSES:substring(0, width - 2) + "┘".

    print headerLine at (left, top).
    for i in range(1, height - 1) { 
        print "¦" at (left, top + i).
        print "¦" at (left + width - 1, top + i).
    }
    print footerLine at (left, top + height - 1).
}

local function KateWindow_drawContent {
    parameter this.

    local top is this:top.
    local left is this:left.
    local width is this:width.
    local height is this:height.
    local innerWidth is width - 4.

    local title is this:titleProvider:call(). // string
    local content is this:contentProvider:call(). // list of strings

    local headerLine is "░" + GRAYBAR:substring(0, 1) + "░ █ " + title + " ░" + GRAYBAR:substring(0, width - 9 - title:length) + "░".
    print headerLine at (left, top).

    for i in range(0, height - 3) {
        if i < content:length {
            local contentLine is content[i].
            print contentLine:substring(0, min(contentLine:length, innerWidth)):padright(innerWidth) at (left + 2, top + 2 + i). // make sure rest of line is erased.
        } else {
            print SPACES:substring(0, innerWidth) at (left + 2, top + 2 + i). // make sure rest of line is erased.
        }
    }
}

local function KateWindow_handleInput {
    parameter this,
              inputCharacter.

    // TODO: Handle special commands (e.g. minimize)
    // Now defer to content handler
    this:inputHandler:handleInput(inputCharacter).
}

local function KateWindow_defaultInputHandler {
    parameter inputCharacter.
    // Do nothing
}