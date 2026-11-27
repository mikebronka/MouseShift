-- MouseShift regression tests. Run from the repository root:
--   lua5.1 tests/run.lua
--
-- Every bug that reached a release gets a test here, so a later fix cannot
-- bring it back.

local load_env = dofile("tests/mock.lua")
local failures, passed = 0, 0

local function check(condition, message)
    if condition then
        passed = passed + 1
        print("ok    " .. message)
    else
        failures = failures + 1
        print("FAIL  " .. message)
    end
end

local SHIFT, CTRL, ALT = 1, 2, 4

-- Default-like keybinds plus common modifier keybinds.
local bindings = {
    ["W"] = "MOVEFORWARD",
    ["S"] = "MOVEBACKWARD",
    ["A"] = "TURNLEFT",
    ["D"] = "TURNRIGHT",
    ["Q"] = "STRAFELEFT",
    ["E"] = "STRAFERIGHT",
    ["SPACE"] = "JUMP",
    ["1"] = "ACTIONBUTTON1",
    ["2"] = "ACTIONBUTTON2",
    ["BUTTON3"] = "MOVEANDSTEER",

    ["SHIFT-1"] = "ACTIONBUTTON7",
    ["SHIFT-2"] = "ACTIONBUTTON8",
    ["CTRL-1"] = "ACTIONBUTTON9",
    ["ALT-2"] = "ACTIONBUTTON20",
    ["CTRL-SHIFT-1"] = "ACTIONBUTTON10",

    ["CTRL-W"] = "ACTIONBUTTON30",   -- 0.3.2: W must not be taken over
    ["SHIFT-A"] = "ACTIONBUTTON31",  -- 0.3.2: A must not be taken over
    ["SHIFT-Q"] = "ACTIONBUTTON32",  -- Q strafes by default: not taken over
    ["SHIFT-SPACE"] = "ACTIONBUTTON40", -- 0.3.3: Space must work again
    ["CTRL-SPACE"] = "ACTIONBUTTON41",
    ["ALT-SPACE"] = "ACTIONBUTTON42",
    ["SHIFT-X"] = "JUMP",            -- jump is never put on another key
    ["SHIFT-Z"] = "MOVEFORWARD",     -- movement is never put on another key
    ["SHIFT-BUTTON1"] = "TARGETSELF", -- left mouse button never taken over
}

local env = load_env(bindings, { SHIFT = "BUTTON5", CTRL = "BUTTON4" })
local ns = env.ns
local shift, ctrl, alt = env.Layer(SHIFT), env.Layer(CTRL), env.Layer(ALT)

print("-- Layers")
check(shift["1"] == "ACTIONBUTTON7", "Shift-1 reaches 1")
check(shift["2"] == "ACTIONBUTTON8", "Shift-2 reaches 2")
check(ctrl["1"] == "ACTIONBUTTON9", "Ctrl-1 reaches 1")
check(env.Layer(SHIFT + CTRL)["1"] == "ACTIONBUTTON10", "Ctrl-Shift-1 reaches 1 with both held")

print("-- Walking keys stay walking keys (0.3.2)")
check(ctrl["W"] == nil, "Ctrl-W does not take over W")
check(shift["A"] == nil, "Shift-A does not take over A")
check(shift["Q"] == nil, "Shift-Q does not take over Q while Q strafes")

print("-- Jump key stays available (0.3.3)")
check(shift["SPACE"] == "ACTIONBUTTON40", "Shift-Space reaches Space")
check(ctrl["SPACE"] == "ACTIONBUTTON41", "Ctrl-Space reaches Space")

print("-- Movement is never put on another key")
check(shift["X"] == nil, "Shift-X (jump) is not put on X")
check(shift["Z"] == nil, "Shift-Z (walk) is not put on Z")

print("-- Main mouse buttons and triggers")
check(shift["BUTTON1"] == nil, "left mouse button never taken over")
check(shift["BUTTON5"] == nil and shift["BUTTON4"] == nil, "trigger buttons never taken over")
check(next(alt) == nil, "no Alt layer without an Alt trigger")

print("-- Trigger checks")
check(ns.CheckTrigger("BUTTON1") ~= nil, "left mouse button refused as trigger")
check(ns.CheckTrigger("BUTTON2") ~= nil, "right mouse button refused as trigger")
check(ns.CheckTrigger("W") ~= nil, "walking key refused as trigger")
check(ns.CheckTrigger("SPACE") ~= nil, "jump key refused as trigger")
check(ns.CheckTrigger("ESCAPE") ~= nil, "Escape refused as trigger")
check(ns.CheckTrigger("LSHIFT") ~= nil, "real Shift refused as trigger")
check(ns.CheckTrigger("BUTTON3") ~= nil, "middle button bound to steering refused as trigger")
check(ns.CheckTrigger("BUTTON4") == nil, "mouse button 4 accepted as trigger")
check(ns.CheckTrigger("F") == nil, "a free keyboard key accepted as trigger")

print("-- Movement protection (0.4)")
local function skippedKeys(mask)
    local keys = {}
    for _, entry in ipairs(ns.skipped[mask] or {}) do keys[entry.key] = entry.action end
    return keys
end
check(skippedKeys(SHIFT)["Q"] == "ACTIONBUTTON32", "Shift-Q is reported as skipped")
check(skippedKeys(CTRL)["W"] == "ACTIONBUTTON30", "Ctrl-W is reported as skipped")
check(ns.IsKeyProtected("W") and ns.IsKeyProtected("Q"), "walking and strafing keys protected by default")
check(not ns.IsKeyProtected("SPACE"), "jump key free by default")
check(not ns.IsKeyProtected("1"), "a non-movement key is never protected")
check(ns.IsKeyProtected("BUTTON3"), "a mouse button used for steering is always protected")

local list = ns.GetMovementKeys()
local order = {}
for _, entry in ipairs(list) do order[#order + 1] = entry.key end
check(table.concat(order, ",") == "W,S,A,D,Q,E,SPACE", "movement keys listed in order (got " .. table.concat(order, ",") .. ")")
local q
for _, entry in ipairs(list) do if entry.key == "Q" then q = entry end end
check(q and q.protected and q.isDefault and #q.bindings == 1 and q.bindings[1].combo == "SHIFT-Q", "Q entry shows its Shift-Q keybind")

ns.SetKeyProtected("Q", false)
check(env.Layer(SHIFT)["Q"] == "ACTIONBUTTON32", "freeing Q lets Shift-Q reach Q")
check(skippedKeys(SHIFT)["Q"] == nil, "a free key is not reported as skipped")
local saved = env.MouseShiftDB.movementKeys.Q
check(saved and saved.action == "STRAFELEFT" and saved.protected == false, "the choice is saved with its movement")

ns.SetKeyProtected("SPACE", true)
check(env.Layer(SHIFT)["SPACE"] == nil, "protecting Space keeps Shift-Space off Space")
check(env.Layer(CTRL)["SPACE"] == nil, "protecting Space applies to every layer")

ns.SetKeyProtected("Q", true)
check(env.MouseShiftDB.movementKeys.Q == nil, "choosing the default again removes the saved choice")

ns.ResetMovementKeys()
check(next(env.MouseShiftDB.movementKeys) == nil, "Defaults clears every choice")
check(env.Layer(SHIFT)["SPACE"] == "ACTIONBUTTON40" and env.Layer(SHIFT)["Q"] == nil, "Defaults restores the default layers")

print("-- Movement protection edge cases (0.4 review)")
-- A choice made for another movement does not count.
env.MouseShiftDB.movementKeys.E = { action = "MOVEFORWARD", protected = false }
check(env.ns.IsKeyProtected("E"), "a choice saved for another movement is ignored")
env.ns.ResetMovementKeys()

-- Changing a key while a layer is switched on.
env.MouseShiftDriver._attr["active-mask"] = SHIFT
env.overrides["SPACE"] = "ACTIONBUTTON40"
env.overrides["1"] = "ACTIONBUTTON7"
check(not ns.IsKeyProtected("SPACE"), "while the Shift layer is on, Space still reads as jump")
local listed = false
for _, entry in ipairs(ns.GetMovementKeys()) do if entry.key == "SPACE" then listed = true end end
check(listed, "while the Shift layer is on, Space stays in the list")
ns.SetKeyProtected("SPACE", true)
check(env.Layer(SHIFT)["SPACE"] == nil, "protecting Space while the layer is on takes effect")
env.overrides = {}
env.MouseShiftDriver._attr["active-mask"] = 0
ns.ResetMovementKeys()

-- Only keybinds the assigned buttons can reach are promised.
local reach = { ["SHIFT-Q"] = "ACTIONBUTTON32", ["ALT-Q"] = "ACTIONBUTTON50" }
for k, v in pairs(bindings) do reach[k] = reach[k] or v end
local env2 = load_env(reach, { SHIFT = "BUTTON5" })
local qEntry
for _, entry in ipairs(env2.ns.GetMovementKeys()) do if entry.key == "Q" then qEntry = entry end end
check(qEntry and #qEntry.bindings == 1 and qEntry.bindings[1].combo == "SHIFT-Q", "Alt-Q is not promised when only Shift is assigned")

-- Saved choices are checked when the addon loads.
local env3 = load_env(bindings, {}, nil, {
    Q = false,                                        -- old 0.4 test build format
    E = { action = 5, protected = true },             -- junk
    SPACE = { action = "JUMP", protected = true },    -- valid
})
check(env3.MouseShiftDB.movementKeys.Q == nil and env3.MouseShiftDB.movementKeys.E == nil, "invalid saved choices are dropped")
check(env3.MouseShiftDB.movementKeys.SPACE ~= nil and env3.ns.IsKeyProtected("SPACE"), "a valid saved choice is kept")

-- Another addon's override on a movement key (0.4 second review):
-- the layer must stay on while the button is held.
local env4 = load_env(bindings, { SHIFT = "BUTTON5" })
env4.overrides["Q"] = "CLICK BindPadMacro:LeftButton"
env4.ns.Apply()
check(env4.Layer(SHIFT)["Q"] == "ACTIONBUTTON32", "a movement key overridden by another addon is not movement")
env4.MouseShiftDriver._attr["active-mask"] = SHIFT
env4.overrides["Q"] = "ACTIONBUTTON32"                -- MouseShift's own layer override
env4.overrides["1"] = "ACTIONBUTTON7"
check(not env4.ns.IsKeyProtected("Q"), "while held, the key still reads as the other addon's binding")
env4.ns.Apply()
check(env4.MouseShiftDriver._attr["active-mask"] == SHIFT, "a rebuild while the button is held keeps the layer on")

print("-- Settings window (smoke test)")
local ui = load_env(bindings, { SHIFT = "BUTTON5", CTRL = "BUTTON4" }, { "Core.lua", "Config.lua" })
local tip = ui.GameTooltip
local function hover(target)
    target._scripts.OnEnter(target)
    return table.concat(tip.lines, "\n")
end
local okOpen, err = pcall(ui.ns.ToggleConfig)
check(okOpen, "settings window opens" .. (okOpen and "" or (": " .. tostring(err))))
local config = ui.MouseShiftConfig
check(config and config:IsShown(), "settings window is shown")

-- Find the frames with tooltips: hit layers and count areas.
local function collect()
    local list = {}
    for _, frame in ipairs(ui.__frames or {}) do
        if frame._scripts.OnEnter then list[#list + 1] = frame end
    end
    return list
end
local tooltips = {}
for _, frame in ipairs(collect()) do
    local okHover, text = pcall(hover, frame)
    check(okHover, "tooltip works" .. (okHover and "" or (": " .. tostring(text))))
    if okHover then tooltips[#tooltips + 1] = text end
end
local all = table.concat(tooltips, "\n---\n")
check(all:find("Shift layer", 1, true) ~= nil, "layer tooltip shows the Shift layer")
check(all:find("Skipped: protected movement keys", 1, true) ~= nil, "layer tooltip lists skipped keys")
check(all:find("Movement protection", 1, true) ~= nil, "movement button has a tooltip")

local okMove, moveErr = pcall(ui.ns.ToggleMovement)
check(okMove, "movement window opens" .. (okMove and "" or (": " .. tostring(moveErr))))
check(ui.MouseShiftMovement and ui.MouseShiftMovement:IsShown(), "movement window is shown")
local rowTips = {}
for _, frame in ipairs(collect()) do
    local okHover, text = pcall(hover, frame)
    if okHover and text:find("^Q: ") then rowTips.Q = text; rowTips.QFrame = frame end
    if okHover and text:find("^SPACE: ") then rowTips.SPACE = text end
end
check(rowTips.Q and rowTips.Q:find("Protected (default)", 1, true), "Q row tooltip says protected by default")
check(rowTips.SPACE and rowTips.SPACE:find("Your mouse button reaches", 1, true), "Space row tooltip shows what it gains")

local okClick, clickErr = pcall(rowTips.QFrame._scripts.OnMouseUp, rowTips.QFrame, "LeftButton")
check(okClick, "clicking the Q row works" .. (okClick and "" or (": " .. tostring(clickErr))))
check(ui.MouseShiftDB.movementKeys.Q and not ui.ns.IsKeyProtected("Q"), "clicking the Q row frees Q")
check(ui.Layer(SHIFT)["Q"] == "ACTIONBUTTON32", "after freeing Q, Shift-Q reaches Q")
pcall(rowTips.QFrame._scripts.OnMouseUp, rowTips.QFrame, "RightButton")
check(ui.MouseShiftDB.movementKeys.Q and ui.MouseShiftDB.movementKeys.Q.protected == false, "a right click on the row does nothing")

print(("%d passed, %d failed"):format(passed, failures))
if failures > 0 then
    os.exit(1)
end
