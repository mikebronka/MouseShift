-- MouseShift test mock: a minimal stand-in for the WoW API, enough to load
-- Core.lua and inspect the layers it builds. Runs on plain Lua 5.1.
--
-- Usage: local env = dofile("tests/mock.lua")(bindings, triggers, files)
-- files defaults to { "Core.lua" }.

return function(bindings, triggers, files)
    local frames = {}

    local function band(a, b)
        local result, bitValue = 0, 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitValue
            end
            a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
        end
        return result
    end

    local function bor(a, b)
        return a + b - band(a, b)
    end

    local env = {}
    setmetatable(env, { __index = function(_, key)
        local value = _G[key]
        if value ~= nil then
            return value
        end
        -- Any other WoW API function does nothing and returns nil.
        return function() end
    end })

    local newFrame
    local methods = {
        SetAttribute = function(self, n, v) self._attr[n] = v end,
        GetAttribute = function(self, n) return self._attr[n] end,
        SetScript = function(self, n, fn) self._scripts[n] = fn end,
        HookScript = function(self, n, fn) self._scripts[n] = fn end,
        GetScript = function(self, n) return self._scripts[n] end,
        GetName = function(self) return self._name end,
        GetParent = function(self) return self._parent end,
        GetFrameLevel = function() return 1 end,
        Show = function(self)
            local wasShown = self._shown
            self._shown = true
            if not wasShown and self._scripts.OnShow then self._scripts.OnShow(self) end
        end,
        Hide = function(self)
            local wasShown = self._shown
            self._shown = false
            if wasShown and self._scripts.OnHide then self._scripts.OnHide(self) end
        end,
        IsShown = function(self) return self._shown == true end,
        SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end,
        SetEnabled = function(self, enabled) self._disabled = not enabled end,
        IsEnabled = function(self) return not self._disabled end,
        SetChecked = function(self, checked) self._checked = checked and true or false end,
        GetChecked = function(self) return self._checked end,
        SetText = function(self, text) self._text = text end,
        GetText = function(self) return self._text end,
        IsMouseOver = function() return true end,
        CreateFontString = function(self) return newFrame(nil, self) end,
        CreateTexture = function(self) return newFrame(nil, self) end,
    }
    newFrame = function(name, parent)
        local frame = { _attr = {}, _scripts = {}, _name = name, _parent = parent }
        return setmetatable(frame, { __index = function(_, method)
            return methods[method] or function() end
        end })
    end

    -- Collects what a tooltip shows, line by line.
    env.GameTooltip = newFrame("GameTooltip")
    env.GameTooltip.lines = {}
    env.GameTooltip.SetOwner = function(self) self.lines = {} end
    env.GameTooltip.SetText = function(self, text) self.lines = { text } end
    env.GameTooltip.AddLine = function(self, text) self.lines[#self.lines + 1] = text end
    env.GameTooltip.AddDoubleLine = function(self, left, right) self.lines[#self.lines + 1] = left .. " | " .. right end

    -- Globals that are tables or strings in the game, not functions.
    env.AddonCompartmentFrame = false
    env.Settings = false
    env.SettingsPanel = false
    env.SOUNDKIT = false
    env.C_AddOns = false
    env.LibStub = false
    env.SHIFT_KEY_TEXT = "Shift"
    env.CTRL_KEY_TEXT = "Ctrl"
    env.ALT_KEY_TEXT = "Alt"
    env.GetBindingText = function(key) return key end

    env.UIParent = newFrame("UIParent")
    env.UISpecialFrames = {}
    env.tinsert = table.insert

    env.__frames = frames
    env.bit = { band = band, bor = bor }
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.CreateFrame = function(_, name, parent)
        local frame = newFrame(name, parent)
        if name then env[name] = frame end
        frames[#frames + 1] = frame
        return frame
    end
    env.InCombatLockdown = function() return false end
    env.C_Timer = {
        After = function() end,
        NewTicker = function() return { Cancel = function() end } end,
    }
    env.SlashCmdList = {}
    -- Override bindings, as the game reports them with checkOverride.
    env.overrides = {}
    env.GetBindingAction = function(key, checkOverride)
        if checkOverride and env.overrides[key] then
            return env.overrides[key]
        end
        return bindings[key] or ""
    end

    local list = {}
    for key, action in pairs(bindings) do
        list[#list + 1] = { action, key }
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)
    env.GetNumBindings = function() return #list end
    env.GetBinding = function(index)
        local entry = list[index]
        if entry then
            return entry[1], entry[2]
        end
    end

    env.MouseShiftDB = { triggers = triggers or {} }

    local ns = {}
    for _, file in ipairs(files or { "Core.lua" }) do
        local chunk = assert(loadfile(file))
        setfenv(chunk, env)
        chunk("MouseShift", ns)
    end

    -- Fire the events the game sends at login.
    for _, frame in ipairs(frames) do
        local handler = frame._scripts.OnEvent
        if handler then
            handler(frame, "ADDON_LOADED", "MouseShift")
            handler(frame, "PLAYER_LOGIN")
        end
    end

    -- Returns a layer as a table: plain key -> action.
    function env.Layer(mask)
        local driver = env.MouseShiftDriver
        local layer = {}
        for i = 1, driver._attr["layer" .. mask .. "-count"] or 0 do
            layer[driver._attr["layer" .. mask .. "-key" .. i]] = driver._attr["layer" .. mask .. "-action" .. i]
        end
        return layer
    end

    env.ns = ns
    return env
end
