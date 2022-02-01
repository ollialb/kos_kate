@lazyGlobal off.

include("kate/core/kate_object").

local MINUSSES is "╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌".
local GRAYBAR  is "░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░".
local SPACES  is  "                                                                                                                           ".

function KateWindow2 {
    parameter id, pleft, ptop, pwidth, pheight, ptitleProvider, pcontentProvider, pInputHandler is KateWindow2_defaultInputHandler@.
    local this is KateObject("KateWindow2", id).
    
    set this:top to ptop.
    set this:left to pleft.
    set this:width to pwidth.
    set this:height to pheight.
    set this:titleProvider to ptitleProvider.
    set this:contentProvider to pcontentProvider.
    set this:inputHandler to pInputHandler.

    this:def("drawFrame", KateWindow2_drawFrame@).
    this:def("drawContent", KateWindow2_drawContent@).
    this:def("handleInput", KateWindow2_handleInput@).

    return this.
}

local function KateWindow2_drawFrame {
    parameter this.

    local top is this:top.
    local left is this:left.
    local width is this:width.
    local height is this:height.

    local title is this:titleProvider:call(). // string
    local headerLine is "░" + GRAYBAR:substring(0, 1) + "░ █ " + title + " ░" + GRAYBAR:substring(0, width - 9 - title:length) + "░".
    print headerLine at (left, top).
}

local function KateWindow2_drawContent {
    parameter this.

    local top is this:top.
    local left is this:left.
    local width is this:width.
    local height is this:height.

    local title is this:titleProvider:call(). // string
    local content is this:contentProvider:call(). // list of strings

    local headerLine is "░" + GRAYBAR:substring(0, 1) + "░ █ " + title + " ░" + GRAYBAR:substring(0, width - 9 - title:length) + "░".
    print headerLine at (left, top).

    for i in range(0, height - 3) {
        if i < content:length {
            local contentLine is content[i].
            print contentLine:substring(0, min(contentLine:length, width)):padright(width) at (left, top + 2 + i). // make sure rest of line is erased.
        } else {
            print SPACES:substring(0, width) at (left, top + 2 + i). // make sure rest of line is erased.
        }
    }
}

local function KateWindow2_handleInput {
    parameter this,
              inputCharacter.

    // TODO: Handle special commands (e.g. minimize)
    // Now defer to content handler
    this:inputHandler:handleInput(inputCharacter).
}

local function KateWindow2_defaultInputHandler {
    parameter inputCharacter.
    // Do nothing
}