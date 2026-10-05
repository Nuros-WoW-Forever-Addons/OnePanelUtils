--[[
    OnePanelUtils - Logger.lua
    Structured logging, severity formatting, and SafeCall exception isolation for OnePanel Suite.
--]]

local Utils = _G.OnePanelUtils or select(2, ...)
local Logger = {}

Logger.LogLevels = {
    DEBUG = 1,
    INFO  = 2,
    WARN  = 3,
    ERROR = 4,
}

Logger.Colors = {
    DEBUG = "|cff808080", -- Grey
    INFO  = "|cff00ccff", -- Cyan
    WARN  = "|cffffcc00", -- Yellow
    ERROR = "|cffff3333", -- Red
}

-------------------------------------------------------------------------------
-- Logging API
-------------------------------------------------------------------------------

--- Set active log level threshold
-- @param level string|number: Log level name ("DEBUG", "INFO", etc.) or numeric priority (1-4)
function Logger:SetLogLevel(level)
    if type(level) == "string" and self.LogLevels[level:upper()] then
        level = self.LogLevels[level:upper()]
    end
    if type(level) == "number" and level >= 1 and level <= 4 then
        if Utils.db then
            Utils.db.logLevel = level
        end
    end
end

--- Check if a given log level is active
-- @param levelName string: Level name to check
-- @return boolean
function Logger:IsLevelEnabled(levelName)
    local minLevel = (Utils.db and Utils.db.logLevel) or self.LogLevels.INFO
    local targetLevel = self.LogLevels[levelName:upper()] or self.LogLevels.INFO
    return targetLevel >= minLevel
end

--- Emit a formatted log message to the chat frame
-- @param tag string: Sub-module or plugin identifier (e.g. "Professions", "TabManager")
-- @param level string: Log level ("DEBUG", "INFO", "WARN", "ERROR")
-- @param message string: The message text to print
function Logger:Log(tag, level, message)
    level = (level or "INFO"):upper()

    if _G.OneSwatter and _G.OneSwatter.Log then
        _G.OneSwatter:Log("OnePanelUtils", level, tag, message)
    end

    if not self:IsLevelEnabled(level) then return end
    
    local color = self.Colors[level] or "|cffffffff"
    local tagStr = tag and ("[" .. tag .. "] ") or ""
    local formatted = string.format("|cff00ccff[OnePanel]|r%s%s[%s] %s|r", 
        color, tagStr, level, tostring(message))
    
    print(formatted)
end

-------------------------------------------------------------------------------
-- SafeCall Exception Isolation API
-------------------------------------------------------------------------------

local function ErrorHandler(err)
    local stack = debugstack(2, 6, 2)
    return {
        errorMsg = tostring(err),
        stackTrace = stack
    }
end

--- Execute a function safely, isolating exceptions and logging detailed diagnostics
-- @param tag string: Component tag for diagnostic tracing (e.g. "OnePanel:Professions")
-- @param func function: Function to execute
-- @param ... any: Arguments to pass to func
-- @return boolean success, ...: Success status followed by return values of func or error detail
function Logger:SafeCall(tag, func, ...)
    if type(func) ~= "function" then
        self:Log(tag, "ERROR", "SafeCall failed: Target is not a function (" .. type(func) .. ")")
        return false, "Target is not a function"
    end
    
    local results = { xpcall(func, ErrorHandler, ...) }
    local success = results[1]
    
    if not success then
        local errDetail = results[2]
        local errMessage = type(errDetail) == "table" and errDetail.errorMsg or tostring(errDetail)
        local stackTrace = type(errDetail) == "table" and errDetail.stackTrace or ""
        
        self:Log(tag, "ERROR", "Execution error caught: " .. errMessage)
        if stackTrace and stackTrace ~= "" and self:IsLevelEnabled("DEBUG") then
            print("|cffff6666Stack Trace:|r\n" .. stackTrace)
        end
        return false, errMessage, stackTrace
    end
    
    return unpack(results)
end

--- Execute an object method safely
-- @param tag string: Component tag
-- @param object table: Object instance containing the method
-- @param methodName string: Name of method on object
-- @param ... any: Arguments to pass to method
-- @return boolean success, ...
function Logger:SafeCallMethod(tag, object, methodName, ...)
    if not object or type(object) ~= "table" then
        self:Log(tag, "ERROR", "SafeCallMethod failed: Invalid target object")
        return false, "Invalid target object"
    end
    
    local method = object[methodName]
    if type(method) ~= "function" then
        self:Log(tag, "ERROR", "SafeCallMethod failed: Method '" .. tostring(methodName) .. "' not found")
        return false, "Method not found"
    end
    
    return self:SafeCall(tag, method, object, ...)
end

-- Register module with Core
Utils:RegisterModule("Logger", Logger)
