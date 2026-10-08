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

-------------------------------------------------------------------------------
-- HiRes Frame Art Theme (UIFrameHiRes Metal Slices)
-------------------------------------------------------------------------------

FrameHelper.HiResOffsets = {
    topEdgeY     = -18,
    leftEdgeX    = 17,
    bottomLeftX  = -11,
    portraitSize = 60,
    portraitX    = 6,
    portraitY    = -7,
    closeX       = -20,
    closeY       = -20,
}

--- Re-apply live alignment offsets to an active HiRes frame
-- @param frame Frame: Target frame
function FrameHelper:UpdateHiResAlignment(frame)
    if not frame or not frame.HiResBorder then return end
    local border = frame.HiResBorder
    local o = self.HiResOffsets
    
    if border.TopEdge and border.TopLeft and border.TopRight then
        border.TopEdge:ClearAllPoints()
        border.TopEdge:SetPoint("TOPLEFT", border.TopLeft, "TOPRIGHT", -8, o.topEdgeY)
        border.TopEdge:SetPoint("TOPRIGHT", border.TopRight, "TOPLEFT", 8, o.topEdgeY)
    end
    
    if border.BottomLeft then
        border.BottomLeft:ClearAllPoints()
        border.BottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o.bottomLeftX, -8)
    end
    
    if border.LeftEdge and border.TopLeft and border.BottomLeft then
        border.LeftEdge:ClearAllPoints()
        border.LeftEdge:SetPoint("TOPLEFT", border.TopLeft, "BOTTOMLEFT", o.leftEdgeX, 0)
        border.LeftEdge:SetPoint("BOTTOMLEFT", border.BottomLeft, "TOPLEFT", 0, 0)
    end
    
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", o.portraitX, o.portraitY)
        frame.PortraitContainer:SetSize(o.portraitSize, o.portraitSize)
        if frame.PortraitContainer.portrait then
            frame.PortraitContainer.portrait:ClearAllPoints()
            frame.PortraitContainer.portrait:SetAllPoints(frame.PortraitContainer)
        end
    end
    
    if frame.CloseButton and border.TopRight then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", border.TopRight, "TOPRIGHT", o.closeX, o.closeY)
    end
end

--- Apply high-resolution custom Blizzard metal frame art using UIFrameHiRes slices
-- @param frame Frame: The parent or host frame (e.g. OnePanelFrame)
-- @param options table|nil: Optional customization table { hasPortrait = true, bgTexture = ... }
function FrameHelper:ApplyHiResFrame(frame, options)
    if not frame then return end
    options = options or {}
    
    local bgTexPath = options.bgTexture or "Interface\\FrameGeneral\\UI-Background-Rock"
    local o = self.HiResOffsets
    
    -- If native NineSlice exists, hide it so our HiRes textures take over
    if frame.NineSlice then
        frame.NineSlice:Hide()
    end
    
    local border = frame.HiResBorder
    if not border then
        border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(frame)
        border:SetFrameLevel(math.max(1, frame:GetFrameLevel()))
        frame.HiResBorder = border
        
        -- Textures definition
        local CORNERS_FILE = "Interface\\FrameGeneral\\UIFrameHiRes"
        local HORIZ_FILE   = "Interface\\FrameGeneral\\UIFrameHiResHorizontal"
        local VERT_FILE    = "Interface\\FrameGeneral\\UIFrameHiResVertical"
        
        -- 1. Background / Center Fill
        local bg = border:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(bgTexPath)
        bg:SetHorizTile(true)
        bg:SetVertTile(true)
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -20)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
        border.Bg = bg
        
        -- 2. Top-Left Corner (Portrait Ring)
        local tl = border:CreateTexture(nil, "OVERLAY", nil, 2)
        tl:SetTexture(CORNERS_FILE)
        tl:SetTexCoord(0, 237/512, 0, 243/256)
        tl:SetSize(118.5, 121.5)
        tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -14, 18)
        border.TopLeft = tl
        
        -- 3. Top-Right Corner (Close Button Box)
        local tr = border:CreateTexture(nil, "OVERLAY", nil, 2)
        tr:SetTexture(CORNERS_FILE)
        tr:SetTexCoord(237/512, 390/512, 4/256, 139/256)
        tr:SetSize(76.5, 67.5)
        tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 18)
        border.TopRight = tr
        
        -- 4. Bottom-Left Corner
        local bl = border:CreateTexture(nil, "OVERLAY", nil, 2)
        bl:SetTexture(CORNERS_FILE)
        bl:SetTexCoord(446/512, 492/512, 0, 50/256)
        bl:SetSize(23, 25)
        bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", o.bottomLeftX, -8)
        border.BottomLeft = bl
        
        -- 5. Bottom-Right Corner
        local br = border:CreateTexture(nil, "OVERLAY", nil, 2)
        br:SetTexture(CORNERS_FILE)
        br:SetTexCoord(394/512, 442/512, 0, 50/256)
        br:SetSize(24, 25)
        br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -8)
        border.BottomRight = br
        
        -- 6. Top Edge (Horizontally Tiling)
        local te = border:CreateTexture(nil, "OVERLAY", nil, 1)
        te:SetTexture(HORIZ_FILE)
        te:SetTexCoord(0, 1, 0, 18/128)
        te:SetHorizTile(true)
        te:SetHeight(9)
        te:SetPoint("TOPLEFT", tl, "TOPRIGHT", -8, o.topEdgeY)
        te:SetPoint("TOPRIGHT", tr, "TOPLEFT", 8, o.topEdgeY)
        border.TopEdge = te
        
        -- 7. Bottom Edge (Horizontally Tiling)
        local be = border:CreateTexture(nil, "OVERLAY", nil, 1)
        be:SetTexture(HORIZ_FILE)
        be:SetTexCoord(0, 1, 71/128, 89/128)
        be:SetHorizTile(true)
        be:SetHeight(9)
        be:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
        be:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
        border.BottomEdge = be
        
        -- 8. Left Edge (Vertically Tiling)
        local le = border:CreateTexture(nil, "OVERLAY", nil, 1)
        le:SetTexture(VERT_FILE)
        le:SetTexCoord(0, 18/64, 0, 1)
        le:SetVertTile(true)
        le:SetWidth(9)
        le:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", o.leftEdgeX, 0)
        le:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
        border.LeftEdge = le
        
        -- 9. Right Edge (Vertically Tiling)
        local re = border:CreateTexture(nil, "OVERLAY", nil, 1)
        re:SetTexture(VERT_FILE)
        re:SetTexCoord(19/64, 37/64, 0, 1)
        re:SetVertTile(true)
        re:SetWidth(9)
        re:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
        re:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
        border.RightEdge = re
    end
    
    border:Show()
    
    -- Position Player Portrait inside the gold/steel ring
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", o.portraitX, o.portraitY)
        frame.PortraitContainer:SetSize(o.portraitSize, o.portraitSize)
        frame.PortraitContainer:SetFrameLevel(border:GetFrameLevel() + 1)
        
        if frame.PortraitContainer.portrait then
            frame.PortraitContainer.portrait:ClearAllPoints()
            frame.PortraitContainer.portrait:SetAllPoints(frame.PortraitContainer)
            frame.PortraitContainer.portrait:Show()
        end
        
        if frame.SetPortraitTextureSizeAndOffset then
            frame.SetPortraitTextureSizeAndOffset = function(self, size, x, y)
                local p = self:GetPortrait()
                if p and frame.PortraitContainer then
                    p:ClearAllPoints()
                    p:SetAllPoints(frame.PortraitContainer)
                end
            end
        end
    elseif frame.portrait then
        frame.portrait:ClearAllPoints()
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", o.portraitX, o.portraitY)
        frame.portrait:SetSize(o.portraitSize, o.portraitSize)
        frame.portrait:Show()
    end
    
    -- Position Close Button into the beveled recess in TopRight corner
    if frame.CloseButton then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", border.TopRight, "TOPRIGHT", o.closeX, o.closeY)
        frame.CloseButton:SetFrameLevel(border:GetFrameLevel() + 5)
    end
    
    -- Position Title Text & Container
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -1)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -38, -1)
        frame.TitleContainer:SetHeight(22)
        frame.TitleContainer:Show()
        if frame.TitleContainer.TitleText then
            frame.TitleContainer.TitleText:Show()
        end
    elseif frame.TitleText then
        frame.TitleText:ClearAllPoints()
        frame.TitleText:SetPoint("TOP", frame, "TOP", 10, -5)
        frame.TitleText:Show()
    end
end

-- Slash command for real-time live alignment
SLASH_ONEPANELALIGN1 = "/opalign"
SlashCmdList["ONEPANELALIGN"] = function(msg)
    local cmd, arg1, arg2 = strsplit(" ", msg or "")
    cmd = (cmd or ""):lower()
    local o = FrameHelper.HiResOffsets
    if not o then return end
    local f = _G["OnePanelFrame"]
    
    if cmd == "top" and tonumber(arg1) then
        o.topEdgeY = tonumber(arg1)
        FrameHelper:UpdateHiResAlignment(f)
        print(string.format("|cff00ff00[OnePanel HiRes]|r topEdgeY set to %d", o.topEdgeY))
    elseif cmd == "left" and tonumber(arg1) then
        o.leftEdgeX = tonumber(arg1)
        o.bottomLeftX = o.leftEdgeX - 28
        FrameHelper:UpdateHiResAlignment(f)
        print(string.format("|cff00ff00[OnePanel HiRes]|r leftEdgeX set to %d", o.leftEdgeX))
    elseif cmd == "portrait" and tonumber(arg1) and tonumber(arg2) then
        o.portraitX = tonumber(arg1)
        o.portraitY = tonumber(arg2)
        FrameHelper:UpdateHiResAlignment(f)
        print(string.format("|cff00ff00[OnePanel HiRes]|r portrait set to (%d, %d)", o.portraitX, o.portraitY))
    elseif cmd == "close" and tonumber(arg1) and tonumber(arg2) then
        o.closeX = tonumber(arg1)
        o.closeY = tonumber(arg2)
        FrameHelper:UpdateHiResAlignment(f)
        print(string.format("|cff00ff00[OnePanel HiRes]|r close button set to (%d, %d)", o.closeX, o.closeY))
    elseif cmd == "print" then
        print(string.format("|cff00ff00[OnePanel HiRes Offsets]|r topEdgeY=%d, leftEdgeX=%d, portrait=(%d, %d), close=(%d, %d)",
            o.topEdgeY, o.leftEdgeX, o.portraitX, o.portraitY, o.closeX, o.closeY))
    else
        print("|cff00ff00OnePanel HiRes Alignment Commands:|r")
        print("  /opalign top <y>          (Current: " .. o.topEdgeY .. ")")
        print("  /opalign left <x>         (Current: " .. o.leftEdgeX .. ")")
        print("  /opalign portrait <x> <y>   (Current: " .. o.portraitX .. ", " .. o.portraitY .. ")")
        print("  /opalign close <x> <y>      (Current: " .. o.closeX .. ", " .. o.closeY .. ")")
        print("  /opalign print            (Prints all current values)")
    end
end


-- Register module with Core
Utils:RegisterModule("FrameHelper", FrameHelper)
