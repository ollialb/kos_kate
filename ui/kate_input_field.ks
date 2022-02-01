@lazyglobal off.

include ("kate/core/kate_object").

local termin is terminal:input.     
local backchar is termin:backspace. 
local delchar is termin:deleteright.
local enterchar is termin:enter.    
local bellchar is char(7).
local cursorchar is "|".

global function KateInputField {
    parameter   id,
                pLabel,
                pMaxlength is (terminal:width),
                pMinlength is 0,
                pInValue is "", // must be of type string or scalar
                pCursorBlink is true.

    local this is KateObject("KateInputField", id).

    set this:label to pLabel.
    set this:maxLength to pMaxlength.
    set this:minLength to pMinlength.
    set this:cursorBlink to pCursorBlink.
    set this:workingstr to choose scalar_to_string(pInValue) if pInValue:istype("scalar") else pInValue.
    set this:displayString to "".
    set this:done to false.
    set this:concatenator to choose number_concatnation@ if pInValue:istype("scalar") else string_concatnation@.
    set this:blinkinter to choose 0.5 if this:cursorblink else 1000.
    set this:blinknextstate to time:seconds.
    set this:blinkchar to "_".
    set this:active to false.

    this:def("uiContent", KateInputString_uiContent@).
    this:def("handleUiInput", KateInputString_handleUiInput@).
    this:def("inputString", KateInputString_inputString@).
    this:def("inputNumber", KateInputString_inputNumber@).
    this:def("updateContent", KateInputString_updateContent@).
    this:def("updateCursor", KateInputString_updateCursor@).
    this:def("setActive", KateInputString_setActive@).


    this:updateContent().
     
    return this.
}

local function KateInputString_setActive {
    parameter this,
              pActive.
    set this:active to pActive.
}

local function KateInputString_inputString {
    parameter this.
    return this:displayString.
}

local function KateInputString_inputNumber {
    parameter this.
    return number_protect(this:displayString).
}

local function KateInputString_uiContent {
    parameter this.

    if this:cursorBlink {
        this:updateContent().
    }

    return this:displayString.
}

local function KateInputString_handleUiInput {
    parameter this,
              inputCharacter.

    if this:workingstr:length > this:maxlength {
        set this:workingstr to this:workingstr:substring(0,this:maxlength).
    }
    
    this:updateCursor().
    
    if inputCharacter = backchar {
        if this:workingstr:length > this:minlength {
          set this:workingstr to this:workingstr:remove(this:workingstr:length - 1,1).
        } else {
          print bellchar.
        }
    } else if inputCharacter = delchar {
        set this:workingstr to "".
        print bellchar.
    } else if inputCharacter = enterchar {
        set this:done to true.
        set this:blinkchar to " ".
    } else {
        set this:workingstr to this:concatenator(this:workingstr,inputCharacter,this:maxlength).
    }

    this:updateContent().
}

local function KateInputString_updateCursor {
    parameter this.

    if not this:active {
        set this:blinkchar to " ".
    } else if this:blinknextstate < time:seconds {
        set this:blinknextstate to this:blinknextstate + this:blinkinter.
        if this:cursorblink {
            set this:blinkchar to choose cursorchar if this:blinkchar <> cursorchar else " ".
        }
    }
}

local function KateInputString_updateContent {
    parameter this.

    this:updateCursor().

    local padchar is (choose this:blinkchar if this:workingstr:length < this:maxlength else "").
    set this:displayString to this:label + (this:workingstr + padchar):padright(this:maxlength).
}

local function scalar_to_string {
    parameter scalar.
    local signchar is choose "-" if scalar < 0 else " ".
    local returnstr to abs(scalar):tostring().
    if returnstr:contains("e") {
        local strsplit is returnstr:split("e").
        local mantissa is strsplit[0].
        local exponent is strsplit[1]:toscalar().
        if mantissa:contains(".") {
            local splitmant is mantissa:split(".").
            set mantissa to splitmant[0] + splitmant[1].
            set exponent to exponent - splitmant[1]:length.
        }
        if exponent < 0 {
            set returnstr to "0." + (" ":padright(abs(exponent + 1))):replace(" ","0") + mantissa.
        } else if exponent > 0 {
            set returnstr to mantissa + (" ":padright(exponent)):replace(" ","0").
        } else {
            set returnstr to mantissa.
        }
    }
    return signchar + returnstr.
}

local function number_protect {
    parameter curentstr.
    if curentstr:length <= 1 { 
        return " 0".
    }
    if curentstr[curentstr:length - 1] = "." {
        return number_protect(curentstr:remove(curentstr:length - 1,1)).
    }
    if curentstr:toscalar(0) = 0 { 
        return " 0".
    }
    return curentstr.
}

local toIgnore is list(
    char(127),
    delchar,
    backchar,
    termin:upcursorone,
    termin:downcursorone,
    termin:leftcursorone,
    termin:rightcursorone,
    termin:homecursor,
    termin:endcursor,
    termin:pagedowncursor,
    termin:pageupcursor
).

local function number_concatnation {
    parameter curentstr,//expects " " as the base string to start with
    cha,
    maxlength.
    if curentstr:length < 1 {
        set curentstr to " ".
    }
    if cha:matchespattern("[0-9-.+]") {
        if curentstr:length < maxlength {
            if cha:matchespattern("[0-9]") {
                return curentstr + cha.
            } else if cha = "." {
                if not curentstr:contains(".") {
                    return curentstr + cha.
                }
            }
        }
        if cha = "-" or cha = "+" {
            if curentstr:contains("-") or cha = "+" {
                return " " + curentstr:remove(0,1).
            } else {
                return cha + curentstr:remove(0,1).
            }
        }
    }
    print bellchar.
    return curentstr.
}

local function string_concatnation {
    parameter curentstr,
    cha,
    maxlength.
    if (unchar(cha) > 31) and (not toIgnore:contains(cha)) {
        if curentstr:length < maxlength {
          return curentstr + cha.
        }
    }
    print bellchar.
    return curentstr.
}

