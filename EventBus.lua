--[[
    OnePanelUtils - EventBus.lua
    Lightweight Pub/Sub event messaging backbone for decoupled cross-module communication.
--]]

local Utils = _G.OnePanelUtils or select(2, ...)
local EventBus = {}

EventBus.listeners = {}

-------------------------------------------------------------------------------
-- Pub/Sub Registration API
-------------------------------------------------------------------------------

--- Register a listener callback for a specific event
-- @param eventName string: Event topic name (e.g. "ONEPANEL_PLUGIN_REGISTERED", "ONEPANEL_TAB_CHANGED")
-- @param callback function: Callback function to invoke when event triggers
-- @param owner table|string|nil: Optional owner reference to assist unregistration
-- @return boolean: Success status
function EventBus:Register(eventName, callback, owner)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        if Utils.Logger then
            Utils.Logger:Log("EventBus", "WARN", "Register failed: Invalid eventName or callback")
        end
        return false
    end
    
    self.listeners[eventName] = self.listeners[eventName] or {}
    
    -- Prevent duplicate handler registration
    for _, item in ipairs(self.listeners[eventName]) do
        if item.callback == callback and item.owner == owner then
            return true
        end
    end
    
    table.insert(self.listeners[eventName], {
        callback = callback,
        owner    = owner
    })
    
    if Utils.Logger then
        Utils.Logger:Log("EventBus", "DEBUG", "Registered listener for event: " .. eventName)
    end
    
    return true
end

--- Unregister event listeners
-- @param eventName string: Event topic name
-- @param callbackOrOwner function|table|string: The callback function or owner object used during registration
function EventBus:Unregister(eventName, callbackOrOwner)
    if not eventName or not self.listeners[eventName] then return end
    
    local list = self.listeners[eventName]
    for i = #list, 1, -1 do
        local item = list[i]
        if item.callback == callbackOrOwner or item.owner == callbackOrOwner then
            table.remove(list, i)
        end
    end
end

--- Unregister all event listeners owned by a specific module/object
-- @param owner table|string: Owner object or tag
function EventBus:UnregisterAllForOwner(owner)
    if not owner then return end
    
    for eventName, list in pairs(self.listeners) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then
                table.remove(list, i)
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher API
-------------------------------------------------------------------------------

--- Trigger/Publish an event to all registered subscribers
-- @param eventName string: Event topic name
-- @param ... any: Parameters passed to event listeners
function EventBus:Trigger(eventName, ...)
    if type(eventName) ~= "string" or not self.listeners[eventName] then
        return
    end
    
    local list = self.listeners[eventName]
    if #list == 0 then return end
    
    if Utils.Logger then
        Utils.Logger:Log("EventBus", "DEBUG", "Triggering event '" .. eventName .. "' to " .. #list .. " listener(s)")
    end
    
    for _, item in ipairs(list) do
        if Utils.Logger and Utils.Logger.SafeCall then
            Utils.Logger:SafeCall("EventBus:" .. eventName, item.callback, ...)
        else
            pcall(item.callback, ...)
        end
    end
end

--- Alias for Trigger
EventBus.Publish = EventBus.Trigger

-- Register module with Core
Utils:RegisterModule("EventBus", EventBus)
