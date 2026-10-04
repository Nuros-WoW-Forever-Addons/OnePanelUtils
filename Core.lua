--[[
    OnePanelUtils - Core.lua
    Core initialization, module registry, and global namespace management for OnePanel Suite.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OnePanelUtils = _G.OnePanelUtils or addonTable

local Utils = _G.OnePanelUtils

Utils.name = addonName
Utils.version = "0.0.1"
Utils.Modules = Utils.Modules or {}
Utils.isInitialized = false

-- Database defaults
local defaultDB = {
    debugMode = false,
    logLevel = 2, -- 1: Debug, 2: Info, 3: Warn, 4: Error
}

-------------------------------------------------------------------------------
-- Module Registry API
-------------------------------------------------------------------------------

--- Register a module within the OnePanelUtils framework
-- @param moduleName string: Unique name of the module (e.g. "Logger", "FrameHelper")
-- @param moduleTable table: Module implementation table
-- @return table: The registered module table
function Utils:RegisterModule(moduleName, moduleTable)
    if not moduleName or type(moduleName) ~= "string" then
        error("OnePanelUtils:RegisterModule requires a valid string for moduleName", 2)
    end
    
    moduleTable = moduleTable or {}
    self.Modules[moduleName] = moduleTable
    self[moduleName] = moduleTable
    
    if self.Logger and self.Logger.Log then
        self.Logger:Log("Core", "DEBUG", "Module registered: " .. moduleName)
    end
    
    return moduleTable
end

--- Retrieve a registered module
-- @param moduleName string: Name of the module
-- @return table|nil: The requested module or nil if not found
function Utils:GetModule(moduleName)
    return self.Modules[moduleName]
end

-------------------------------------------------------------------------------
-- Initialization & Event Handling
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OnePanelUtils_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- SavedVariables setup
        _G.OnePanelUtilsDB = _G.OnePanelUtilsDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OnePanelUtilsDB[k] == nil then
                _G.OnePanelUtilsDB[k] = v
            end
        end
        Utils.db = _G.OnePanelUtilsDB
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        Utils.isInitialized = true
        if Utils.Logger then
            Utils.Logger:Log("Core", "INFO", "OnePanelUtils v" .. Utils.version .. " initialized successfully.")
        end
        
        -- Fire initialization on registered modules if present
        for name, module in pairs(Utils.Modules) do
            if type(module.OnInitialize) == "function" then
                if Utils.Logger and Utils.Logger.SafeCall then
                    Utils.Logger:SafeCall("Module:" .. name, module.OnInitialize, module)
                else
                    pcall(module.OnInitialize, module)
                end
            end
        end
        
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

--- Utility method to print formatted messages to chat frame
-- @param msg string: Message to output
function Utils:Print(msg)
    print("|cff00ccff[OnePanelUtils]|r " .. tostring(msg))
end
