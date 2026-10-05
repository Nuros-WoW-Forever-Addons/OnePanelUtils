--[[
    OnePanelUtils - FrameHelper.lua
    Frame lifecycle, reparenting, strata harmonization, BackdropTemplate helpers, Esc handling, and class icon helpers.
--]]

local Utils = _G.OnePanelUtils or select(2, ...)
local FrameHelper = {}

-- Fallback Class Icon Coordinates for UI-Classes-Circles texture
local FallbackClassCoords = {
    ["WARRIOR"]     = {0, 0.25, 0, 0.25},
    ["MAGE"]        = {0.25, 0.5, 0, 0.25},
    ["ROGUE"]       = {0.5, 0.75, 0, 0.25},
    ["DRUID"]       = {0.75, 1.0, 0, 0.25},
    ["HUNTER"]      = {0, 0.25, 0.25, 0.5},
    ["SHAMAN"]      = {0.25, 0.5, 0.25, 0.5},
    ["PRIEST"]      = {0.5, 0.75, 0.25, 0.5},
    ["WARLOCK"]     = {0.75, 1.0, 0.25, 0.5},
    ["PALADIN"]     = {0, 0.25, 0.5, 0.75},
    ["DEATHKNIGHT"] = {0.25, 0.5, 0.5, 0.75},
    ["MONK"]        = {0.5, 0.75, 0.5, 0.75},
    ["DEMONHUNTER"] = {0.75, 1.0, 0.5, 0.75},
    ["EVOKER"]      = {0, 0.25, 0.75, 1.0},
}

-------------------------------------------------------------------------------
-- Class Icon Helper
-------------------------------------------------------------------------------

--- Set a texture frame to display a unit's circular class icon
-- @param texture Texture: Target texture object
-- @param classFile string|nil: Class filename (e.g. "DRUID", "WARRIOR"); defaults to player class
function FrameHelper:SetClassIcon(texture, classFile)
    if not texture or type(texture) ~= "table" then return end
    
    if not classFile then
        classFile = select(2, UnitClass("player"))
    end
    classFile = (classFile or "WARRIOR"):upper()
    
    texture:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    
    local coords = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]) or FallbackClassCoords[classFile]
    if coords then
        texture:SetTexCoord(unpack(coords))
    else
        texture:SetTexCoord(0, 0.25, 0, 0.25)
    end
end

-------------------------------------------------------------------------------
-- Frame Reparenting & Anchoring Helpers
-------------------------------------------------------------------------------

--- Reparent a frame safely while managing constraints and points
-- @param childFrame Frame: The child frame to reparent
-- @param parentFrame Frame: Target parent container frame
-- @param keepPoints boolean|nil: If true, preserves existing anchors; if false/nil, clears points and sets SetAllPoints
-- @return boolean: Success status
function FrameHelper:ReparentFrame(childFrame, parentFrame, keepPoints)
    if not childFrame or not parentFrame then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "WARN", "ReparentFrame failed: Invalid frame references")
        end
        return false
    end
    
    if InCombatLockdown and InCombatLockdown() and childFrame:IsProtected() then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "ERROR", "Cannot reparent protected frame during combat lockdown")
        end
        return false
    end
    
    childFrame:SetParent(parentFrame)
    if not keepPoints then
        childFrame:ClearAllPoints()
        childFrame:SetAllPoints(parentFrame)
    end
    
    self:HarmonizeStrataAndLevel(childFrame, parentFrame)
    return true
end

--- Harmonize strata and frame level relative to a parent frame
-- @param childFrame Frame: Target frame to adjust
-- @param parentFrame Frame: Reference parent frame
-- @param levelOffset number|nil: Optional frame level offset above parent (default: 1)
function FrameHelper:HarmonizeStrataAndLevel(childFrame, parentFrame, levelOffset)
    if not childFrame or not parentFrame then return end
    
    levelOffset = levelOffset or 1
    
    local parentStrata = parentFrame:GetFrameStrata()
    if parentStrata and childFrame.SetFrameStrata then
        childFrame:SetFrameStrata(parentStrata)
    end
    
    local parentLevel = parentFrame:GetFrameLevel()
    if parentLevel and childFrame.SetFrameLevel then
        childFrame:SetFrameLevel(math.max(1, parentLevel + levelOffset))
    end
end

-------------------------------------------------------------------------------
-- Escape Key (UISpecialFrames) Management
-------------------------------------------------------------------------------

--- Register a frame to close on Escape key press via Blizzard's UISpecialFrames
-- @param frameOrName Frame|string: Frame instance or frame global name string
-- @return boolean: True if successfully registered
function FrameHelper:RegisterEscClose(frameOrName)
    local frameName = type(frameOrName) == "table" and frameOrName:GetName() or frameOrName
    if type(frameName) ~= "string" or frameName == "" then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "WARN", "RegisterEscClose requires a named frame")
        end
        return false
    end
    
    for i, name in ipairs(UISpecialFrames) do
        if name == frameName then
            return true -- Already registered
        end
    end
    
    table.insert(UISpecialFrames, frameName)
    return true
end

--- Remove a frame from UISpecialFrames
-- @param frameOrName Frame|string: Frame instance or frame global name string
function FrameHelper:UnregisterEscClose(frameOrName)
    local frameName = type(frameOrName) == "table" and frameOrName:GetName() or frameOrName
    if type(frameName) ~= "string" then end
    
    for i, name in ipairs(UISpecialFrames) do
        if name == frameName then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end

-------------------------------------------------------------------------------
-- Backdrop & Aesthetic Helpers
-------------------------------------------------------------------------------

--- Apply standardized Blizzard Backdrop to a frame (supports modern BackdropTemplate)
-- @param frame Frame: Target frame
-- @param bgFile string|nil: Background texture path
-- @param edgeFile string|nil: Border edge texture path
-- @param tileSize number|nil: Tile size
-- @param edgeSize number|nil: Border edge size
-- @param insets table|nil: Border inset table {left=x, right=x, top=x, bottom=x}
function FrameHelper:ApplyBackdrop(frame, bgFile, edgeFile, tileSize, edgeSize, insets)
    if not frame then return end
    
    -- Ensure frame supports Backdrop template on modern client runtimes
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        frame:OnBackdropLoaded()
    end
    
    if not frame.SetBackdrop then return end
    
    local backdropTable = {
        bgFile   = bgFile or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = edgeFile or "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = tileSize or 32,
        edgeSize = edgeSize or 32,
        insets   = insets or { left = 11, right = 12, top = 12, bottom = 11 }
    }
    
    frame:SetBackdrop(backdropTable)
end

-------------------------------------------------------------------------------
-- Container & Window Helper Creation
-------------------------------------------------------------------------------

--- Create a standard sub-container frame anchored to a parent
-- @param parentFrame Frame: Parent frame
-- @param name string|nil: Global frame name
-- @return Frame: Created container frame
function FrameHelper:CreateContainerFrame(parentFrame, name)
    local container = CreateFrame("Frame", name, parentFrame)
    container:SetAllPoints(parentFrame)
    self:HarmonizeStrataAndLevel(container, parentFrame, 1)
    return container
end

--- Create a standard draggable title bar header for a frame
-- @param frame Frame: Target frame to attach title bar to
-- @param titleText string: Text to render on title header
-- @return Texture, FontString: Returns drag handle texture and title FontString
function FrameHelper:AttachTitleBar(frame, titleText)
    if not frame then return nil end
    
    -- Title FontString
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -10)
    title:SetText(titleText or "")
    frame.TitleText = title
    
    -- Enable dragging if requested
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not InCombatLockdown or not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    
    return title
end

-- Register module with Core
Utils:RegisterModule("FrameHelper", FrameHelper)
