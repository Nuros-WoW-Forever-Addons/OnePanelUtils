--[[
    OnePanelUtils - Core.lua
    Core initialization, module registry, global namespace management,
    and persistent copy dialog frame inspector dump (/opdump) for OnePanel Suite.
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
-- Persistent Frame Inspection & Copy Tool (/opdump)
-------------------------------------------------------------------------------

local function CreateCopyDialog()
    if _G.OnePanelCopyDialog then return _G.OnePanelCopyDialog end
    
    local copyBox = CreateFrame("Frame", "OnePanelCopyDialog", UIParent, "DialogBoxFrame")
    copyBox:SetSize(640, 520)
    copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    copyBox:SetFrameStrata("FULLSCREEN_DIALOG")
    copyBox:SetToplevel(true)
    copyBox:SetMovable(true)
    copyBox:EnableMouse(true)
    copyBox:RegisterForDrag("LeftButton")
    copyBox:SetScript("OnDragStart", copyBox.StartMoving)
    copyBox:SetScript("OnDragStop", copyBox.StopMovingOrSizing)
    copyBox:Hide()
    
    local title = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", copyBox, "TOPLEFT", 16, -14)
    title:SetText("|cffffd100OnePanel Frame Inspector Dump (/opdump)|r")
    
    local sf = CreateFrame("ScrollFrame", "OnePanelCopyDialogScrollFrame", copyBox, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -36)
    sf:SetPoint("BOTTOMRIGHT", -36, 42)
    
    local eb = CreateFrame("EditBox", "OnePanelCopyDialogEditBox", sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontSmall)
    eb:SetWidth(560)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() copyBox:Hide() end)
    sf:SetScrollChild(eb)
    copyBox.editBox = eb
    
    local closeBtn = CreateFrame("Button", nil, copyBox, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", copyBox, "BOTTOMRIGHT", -16, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() copyBox:Hide() end)
    
    local selectBtn = CreateFrame("Button", nil, copyBox, "UIPanelButtonTemplate")
    selectBtn:SetSize(140, 22)
    selectBtn:SetPoint("BOTTOMRIGHT", closeBtn, "BOTTOMLEFT", -8, 0)
    selectBtn:SetText("Select All (Cmd+C)")
    selectBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)
    
    if table and table.insert and UISpecialFrames then
        table.insert(UISpecialFrames, "OnePanelCopyDialog")
    end
    
    return copyBox
end

local function DumpFrameDetails(target)
    if not target then return "Target is nil." end
    
    local name = target:GetName() or "Anonymous"
    local objType = target.GetObjectType and target:GetObjectType() or type(target)
    
    local out = string.format("=== DUMP: %s ===\n", name)
    out = out .. string.format("Type: %s\n", objType)
    out = out .. string.format("Dimensions: %.1f x %.1f\n", target:GetWidth() or 0, target:GetHeight() or 0)
    
    if target.GetParent then
        local p = target:GetParent()
        out = out .. string.format("Parent: %s\n", p and (p:GetName() or "<Anon>") or "None")
    end
    if target.GetFrameStrata then
        out = out .. string.format("Strata: %s | Level: %d\n", target:GetFrameStrata() or "nil", target:GetFrameLevel() or 0)
    end
    if target.IsShown then
        out = out .. string.format("IsShown: %s | IsVisible: %s\n", tostring(target:IsShown()), tostring(target:IsVisible()))
    end
    
    -- Anchors / Points
    out = out .. "\n--- ANCHORS / POINTS ---\n"
    local numPoints = target.GetNumPoints and target:GetNumPoints() or 0
    for i = 1, numPoints do
        local point, relTo, relPoint, x, y = target:GetPoint(i)
        local relName = relTo and (relTo:GetName() or "<Anon>") or "nil"
        out = out .. string.format("[%d] %s -> %s:%s (%.1f, %.1f)\n", i, tostring(point), relName, tostring(relPoint), x or 0, y or 0)
    end
    
    -- Sub-regions (Textures & FontStrings)
    if target.GetRegions then
        out = out .. "\n--- REGIONS (Textures & FontStrings) ---\n"
        local regions = { target:GetRegions() }
        for idx, reg in ipairs(regions) do
            local regType = reg:GetObjectType()
            local regName = reg:GetName() or ("Region" .. idx)
            local layer = reg.GetDrawLayer and reg:GetDrawLayer() or ""
            
            if regType == "Texture" then
                local texPath = reg.GetTexture and reg:GetTexture() or ""
                local atlas = reg.GetAtlas and reg:GetAtlas() or ""
                out = out .. string.format("[%d] Texture (%s) Layer:%s | Tex:%s | Atlas:%s | Size:%.1fx%.1f\n",
                    idx, regName, layer, tostring(texPath), tostring(atlas), reg:GetWidth() or 0, reg:GetHeight() or 0)
            elseif regType == "FontString" then
                local txt = reg.GetText and reg:GetText() or ""
                out = out .. string.format("[%d] FontString (%s) Layer:%s | Text:\"%s\" | Size:%.1fx%.1f\n",
                    idx, regName, layer, tostring(txt), reg:GetWidth() or 0, reg:GetHeight() or 0)
            else
                out = out .. string.format("[%d] %s (%s)\n", idx, regType, regName)
            end
        end
    end
    
    -- Child Frames
    if target.GetChildren then
        out = out .. "\n--- CHILD FRAMES ---\n"
        local children = { target:GetChildren() }
        for idx, child in ipairs(children) do
            local cName = child:GetName() or "AnonChild"
            local cType = child:GetObjectType()
            out = out .. string.format("[%d] %s (%s) Size:%.1fx%.1f\n", idx, cType, cName, child:GetWidth() or 0, child:GetHeight() or 0)
        end
    end
    
    -- NineSlice & Backdrop Inspection
    if target.GetBackdrop then
        local bd = target:GetBackdrop()
        if bd then
            out = out .. "\n--- BACKDROP (9-SLICE / BORDER) INFO ---\n"
            out = out .. string.format("bgFile: %s\nedgeFile: %s\n", tostring(bd.bgFile), tostring(bd.edgeFile))
            out = out .. string.format("tileSize: %s | edgeSize: %s | tile: %s\n", tostring(bd.tileSize), tostring(bd.edgeSize), tostring(bd.tile))
            if bd.insets then
                out = out .. string.format("insets: Left:%s Right:%s Top:%s Bottom:%s\n", tostring(bd.insets.left), tostring(bd.insets.right), tostring(bd.insets.top), tostring(bd.insets.bottom))
            end
        end
    end

    local ns = target.NineSlice or (type(target) == "table" and target.NineSliceLayout)
    if ns or (type(target) == "table" and target.layoutType) then
        out = out .. "\n--- NINESLICE PIECES & ATLASES ---\n"
        if type(target) == "table" and target.layoutType then
            out = out .. string.format("LayoutType: %s\n", tostring(target.layoutType))
        end
        if type(ns) == "table" then
            if ns.layoutType then
                out = out .. string.format("NineSlice LayoutType: %s\n", tostring(ns.layoutType))
            end
            local pieces = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
            for _, pieceName in ipairs(pieces) do
                local piece = ns[pieceName]
                if piece and piece.GetObjectType and piece:GetObjectType() == "Texture" then
                    local atlas = piece.GetAtlas and piece:GetAtlas() or "None"
                    local tex = piece.GetTexture and piece:GetTexture() or "None"
                    out = out .. string.format("Piece [%s]: Atlas=%s | File=%s\n", pieceName, tostring(atlas), tostring(tex))
                end
            end
        end
    end

    -- Key Table Fields & Sub-objects
    out = out .. "\n--- SUB-ELEMENTS / KEYS ---\n"
    if type(target) == "table" then
        for k, v in pairs(target) do
            local t = type(v)
            if t == "table" and v.GetObjectType then
                out = out .. string.format("[%s] => %s (%s)\n", tostring(k), v:GetObjectType(), v:GetName() or "Anon")
            elseif t == "string" or t == "number" or t == "boolean" then
                out = out .. string.format("[%s] => %s\n", tostring(k), tostring(v))
            end
        end
    end
    
    return out
end

-- Slash command: /opdump [FrameName] (or hover frame)
SLASH_ONEPANELDUMP1 = "/opdump"
SlashCmdList["ONEPANELDUMP"] = function(msg)
    local frameName = (msg and msg ~= "") and msg:match("^%s*(.-)%s*$") or nil
    local target = nil
    
    if frameName and frameName ~= "" then
        target = _G[frameName]
    end
    
    if not target then
        if GetMouseFoci then
            local foci = GetMouseFoci()
            target = foci and foci[1]
        elseif GetMouseFocus then
            target = GetMouseFocus()
        end
    end
    
    if not target then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OnePanel Dump]|r No target frame found under mouse or with specified global name. Usage: /opdump [FrameName] or hover over frame.")
        end
        return
    end
    
    local dialog = CreateCopyDialog()
    local text = DumpFrameDetails(target)
    dialog.editBox:SetText(text)
    dialog:Show()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
end

-- Slash command: /opbutton [OptionalButtonName]
-- Usage: Hover over a button and type /opbutton, or type /opbutton CharacterFrameTab1
SLASH_ONEPANELBUTTON1 = "/opbutton"
SlashCmdList["ONEPANELBUTTON"] = function(msg)
    local name = (msg and msg ~= "") and msg:match("^%s*(.-)%s*$") or nil
    local btn = name and _G[name]
    
    if not btn then
        if GetMouseFoci then
            local foci = GetMouseFoci()
            btn = foci and foci[1]
        elseif GetMouseFocus then
            btn = GetMouseFocus()
        end
    end

    if not btn or not btn.GetObjectType then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OnePanelUtils]|r Target button not found! Usage: /opbutton [ButtonName] or hover over button.")
        end
        return
    end

    local out = "=== BUTTON INSPECTION: " .. (btn:GetName() or "Anonymous") .. " ===\n"
    out = out .. string.format("Type: %s\nDimensions: %.1f x %.1f\n", btn:GetObjectType(), btn:GetWidth() or 0, btn:GetHeight() or 0)

    if btn.GetParent then
        local p = btn:GetParent()
        out = out .. string.format("Parent: %s\n", p and (p:GetName() or "<Anon>") or "None")
    end

    -- Check textures and atlases across button states
    if btn.GetNormalTexture then
        local states = {
            {"Normal", btn:GetNormalTexture()},
            {"Pushed", btn:GetPushedTexture()},
            {"Highlight", btn:GetHighlightTexture()},
            {"Disabled", btn:GetDisabledTexture()},
        }

        out = out .. "\n--- BUTTON STATE TEXTURES ---\n"
        for _, stateInfo in ipairs(states) do
            local stateName, tex = stateInfo[1], stateInfo[2]
            if tex then
                local atlas = tex.GetAtlas and tex:GetAtlas() or "None"
                local texturePath = tex.GetTexture and tex:GetTexture() or "None"
                out = out .. string.format("[%s]\n  Atlas: %s\n  File/ID: %s\n", stateName, tostring(atlas), tostring(texturePath))
            else
                out = out .. string.format("[%s] None\n", stateName)
            end
        end
    end

    -- Inspect child regions (overlays, icons, text font strings)
    if btn.GetRegions then
        out = out .. "\n--- REGIONS / FONTSTRINGS ---\n"
        local regions = { btn:GetRegions() }
        for i, region in ipairs(regions) do
            local regType = region:GetObjectType()
            local regName = region:GetName() or ("Region" .. i)
            if regType == "Texture" then
                local atlas = region.GetAtlas and region:GetAtlas() or "None"
                local tex = region.GetTexture and region:GetTexture() or "None"
                out = out .. string.format("Texture [%s]: Atlas=%s | File=%s\n", regName, tostring(atlas), tostring(tex))
            elseif regType == "FontString" then
                local fontName = region.GetFont and select(1, region:GetFont()) or "None"
                local fontHeight = region.GetFont and select(2, region:GetFont()) or 0
                local txt = region.GetText and region:GetText() or ""
                out = out .. string.format("FontString [%s]: Text='%s' | Font=%s (%.1f pt)\n", regName, txt, tostring(fontName), fontHeight or 0)
            end
        end
    end

    local dialog = CreateCopyDialog()
    dialog.editBox:SetText(out)
    dialog:Show()
    dialog.editBox:SetFocus()
    dialog.editBox:HighlightText()
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
