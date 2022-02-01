@lazyGlobal off.

global function kate_toggle {
    parameter currentState, newState, // Boolean
              toggleAction.           // Delegate

    if (not currentState and newState) or (currentState and not newState) {
        toggleAction().
    }
}