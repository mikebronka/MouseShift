-- MouseShift test mock: a minimal stand-in for the WoW API, enough to load
-- Core.lua and inspect the layers it builds. Runs on plain Lua 5.1.
--
-- Usage: local env = dofile("tests/mock.lua")(bindings, triggers)

return function(bindings, triggers)
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

    local function newFrame(name)
        local frame = { _attr = {}, _scripts = {}, _name = name }
        return setmetatable(frame, { __index = function(_, method)
            if method == "SetAttribute" then
                return function(self, n, v) self._attr[n] = v end
            elseif method == "GetAttribute" then
                return function(self, n) return self._attr[n] end
            elseif method == "SetScript" or method == "HookScript" then
                return function(self, n, fn) self._scripts[n] = fn end
            elseif method == "GetName" then
                return function(self) return self._name end
            end
            return function() end
        end })
    end

    env.bit = { band = band, bor = bor }
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.CreateFrame = function(_, name)
        local frame = newFrame(name)
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
    env.GetBindingAction = function(key) return bindings[key] or "" end

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
    local chunk = assert(loadfile("Core.lua"))
    setfenv(chunk, env)
    chunk("MouseShift", ns)

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
