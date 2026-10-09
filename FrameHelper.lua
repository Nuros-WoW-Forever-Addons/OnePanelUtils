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
-- Metal & HiRes Frame Art Theme (UIFrameMetal / UIFrameHiRes)
-------------------------------------------------------------------------------

FrameHelper.CurrentTheme = "Metal"

FrameHelper.ThemeConfigs = {
    ["Metal"] = {
        name        = "Metal (1x Standard)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameMetal",
        horizFile   = "Interface\\FrameGeneral\\UIFrameMetalHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameMetalVertical",
        
        -- TopLeft (Portrait Ring)
        tlCoords = { 136/512, 267/512, 136/512, 267/512 },
        tlW = 132.0, tlH = 132.0,
        tlX = -13, tlY = 14,
        
        -- TopRight (Close Box)
        trCoords = { 0/512, 131/512, 148/512, 267/512 },
        trW = 132.0, trH = 120.0,
        trX = 0, trY = 2,
        
        -- BottomLeft
        blCoords = { 10/512, 50/512, 80/512, 132/512 },
        blW = 40, blH = 52,
        blX = -5, blY = -4,
        
        -- BottomRight
        brCoords = { 220/512, 266/512, 80/512, 132/512 },
        brW = 46, brH = 52,
        brX = 1, brY = -4,
        
        -- TopEdge
        teCoords = { 0, 1, 124/512, 133/512 },
        teH = 10,
        teY = -13,
        teLeftX = 0,
        teRightX = 0,
        
        -- Header Divider (Bottom bar of double top header)
        hdCoords = { 0, 1, 149/512, 157/512 },
        hdH = 8,
        hdY = -32,
        hdLeftX = 0,
        hdRightX = 0,
        
        -- Vertical Divider (between main panel and side panel)
        vdCoords = { 258/512, 265/512, 0, 1 },
        vdW = 7,
        vdX = 1,
        vdTopY = 11,
        vdBotY = -9,
        
        -- BottomEdge
        beCoords = { 0, 1, 167/512, 178/512 },
        beH = 10,
        beY = -1,
        beLeftX = 0,
        beRightX = 0,
        
        -- LeftEdge
        leCoords = { 11/512, 18/512, 0, 1 },
        leW = 7,
        leX = 9,
        leTopY = 0,
        leBotY = 0,
        
        -- RightEdge
        reCoords = { 258/512, 265/512, 0, 1 },
        reW = 7,
        reX = 0,
        reTopY = 0,
        reBotY = 0,
        
        -- Portrait Center & Size
        portraitX = -7,
        portraitY = 7,
        portraitSize = 60,
        
        -- Close Button Center
        closeX = -13.5,
        closeY = -14.5,
        
        -- Title Centering
        titleX = 0,
        titleY = -13,
        
        -- Background Insets (contained within metal borders)
        bgLeft = 0,
        bgRight = -3,
        bgTop = -3,
        bgBottom = 0,
    },
    ["HiRes"] = {
        name        = "HiRes (2x Scaled)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameHiRes",
        horizFile   = "Interface\\FrameGeneral\\UIFrameHiResHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameHiResVertical",
        
        tlCoords = { 0, 237/512, 0, 243/256 },
        tlW = 118.5, tlH = 121.5,
        tlX = -14, tlY = 18,
        
        trCoords = { 237/512, 390/512, 4/256, 139/256 },
        trW = 76.5, trH = 67.5,
        trX = 4, trY = 18,
        
        blCoords = { 446/512, 492/512, 0, 50/256 },
        blW = 23, blH = 25,
        blX = -11, blY = -8,
        
        brCoords = { 394/512, 442/512, 0, 50/256 },
        brW = 24, brH = 25,
        brX = 4, brY = -8,
        
        teCoords = { 0, 1, 0, 18/128 },
        teH = 9,
        teY = 3,
        teLeftX = -8,
        teRightX = 8,
        
        hdCoords = { 0, 1, 58/128, 70/128 },
        hdH = 12,
        hdY = -23,
        hdLeftX = -8,
        hdRightX = 8,
        
        -- Vertical Divider
        vdCoords = { 19/64, 37/64, 0, 1 },
        vdW = 9,
        vdX = 1,
        vdTopY = 10,
        vdBotY = -14,
        
        beCoords = { 0, 1, 71/128, 89/128 },
        beH = 9,
        beY = 0,
        beLeftX = 0,
        beRightX = 0,
        
        leCoords = { 0, 18/64, 0, 1 },
        leW = 9,
        leX = 12,
        leTopY = 0,
        leBotY = 0,
        
        reCoords = { 19/64, 37/64, 0, 1 },
        reW = 9,
        reX = 0,
        reTopY = 0,
        reBotY = 0,
        
        portraitX = 1,
        portraitY = -7,
        portraitSize = 60,
        
        closeX = -15,
        closeY = -15,
        
        titleX = 0,
        titleY = -14,
        
        bgLeft = 0,
        bgRight = -3,
        bgTop = -3,
        bgBottom = 0,
    }
}

--- Apply custom Blizzard metal frame art using selected theme config
-- @param frame Frame: The parent or host frame (e.g. OnePanelFrame)
-- @param options table|nil: Optional customization table { theme = "Metal"|"HiRes", bgTexture = ... }
function FrameHelper:ApplyHiResFrame(frame, options)
    if not frame then return end
    options = options or {}
    
    local themeKey = options.theme or self.CurrentTheme or "Metal"
    local cfg = self.ThemeConfigs[themeKey] or self.ThemeConfigs["Metal"]
    self.CurrentTheme = themeKey
    
    local bgTexPath = options.bgTexture or "Interface\\FrameGeneral\\UI-Background-Marble"
    
    -- Hide Blizzard native NineSlice and TopTileStreaks
    if frame.NineSlice then
        frame.NineSlice:Hide()
    end
    if frame.TopTileStreaks then
        frame.TopTileStreaks:Hide()
    end
    
    -- 1. Master Background Texture (anchored on frame, securely tucked under metal borders)
    if not frame.Bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        frame.Bg = bg
    end
    frame.Bg:ClearAllPoints()
    frame.Bg:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.bgLeft or 0, cfg.bgTop or -3)
    frame.Bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cfg.bgRight or -3, cfg.bgBottom or 0)
    frame.Bg:SetHorizTile(false)
    frame.Bg:SetVertTile(false)
    frame.Bg:SetTexCoord(0, 1, 0, 1)
    frame.Bg:SetTexture(bgTexPath)
    frame.Bg:SetVertexColor(0.2, 0.2, 0.2, 1.0)
    frame.Bg:Show()
    
    local border = frame.HiResBorder
    if not border then
        border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(frame)
        -- Set border to higher level than inner content so it sits on top of edges
        border:SetFrameLevel(frame:GetFrameLevel() + 10)
        frame.HiResBorder = border
        
        border.Bg = frame.Bg
        
        -- 2. Top-Left Corner (Portrait Ring)
        local tl = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.TopLeft = tl
        
        -- 3. Top-Right Corner (Close Button Box)
        local tr = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.TopRight = tr
        
        -- 4. Bottom-Left Corner
        local bl = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.BottomLeft = bl
        
        -- 5. Bottom-Right Corner
        local br = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.BottomRight = br
        
        -- 6. Top Edge (Horizontally Tiling)
        local te = border:CreateTexture(nil, "OVERLAY", nil, 1)
        te:SetHorizTile(true)
        border.TopEdge = te
        
        -- 7. Bottom Edge (Horizontally Tiling)
        local be = border:CreateTexture(nil, "OVERLAY", nil, 1)
        be:SetHorizTile(true)
        border.BottomEdge = be
        
        -- 8. Left Edge (Vertically Tiling)
        local le = border:CreateTexture(nil, "OVERLAY", nil, 1)
        le:SetVertTile(true)
        border.LeftEdge = le
        
        -- 9. Right Edge (Vertically Tiling)
        local re = border:CreateTexture(nil, "OVERLAY", nil, 1)
        re:SetVertTile(true)
        border.RightEdge = re
        
        -- 10. Header Divider (Bottom bar of double top header)
        local hd = border:CreateTexture(nil, "OVERLAY", nil, 1)
        hd:SetHorizTile(true)
        border.HeaderDivider = hd
    end
    
    -- Ensure HeaderDivider exists even if border was created prior to its addition
    if not border.HeaderDivider then
        local hd = border:CreateTexture(nil, "OVERLAY", nil, 1)
        hd:SetHorizTile(true)
        border.HeaderDivider = hd
    end
    if border.TitleBg then
        border.TitleBg:Hide()
    end
    
    -- Ensure border is at frame level + 10
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    -- Update Textures & Coordinates from active theme config
    border.TopLeft:SetTexture(cfg.cornersFile)
    border.TopLeft:SetTexCoord(unpack(cfg.tlCoords))
    border.TopLeft:ClearAllPoints()
    border.TopLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.tlX, cfg.tlY)
    border.TopLeft:SetSize(cfg.tlW, cfg.tlH)
    
    border.TopRight:SetTexture(cfg.cornersFile)
    border.TopRight:SetTexCoord(unpack(cfg.trCoords))
    border.TopRight:ClearAllPoints()
    border.TopRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", cfg.trX, cfg.trY)
    border.TopRight:SetSize(cfg.trW, cfg.trH)
    
    border.BottomLeft:SetTexture(cfg.cornersFile)
    border.BottomLeft:SetTexCoord(unpack(cfg.blCoords))
    border.BottomLeft:ClearAllPoints()
    border.BottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cfg.blX, cfg.blY)
    border.BottomLeft:SetSize(cfg.blW, cfg.blH)
    
    border.BottomRight:SetTexture(cfg.cornersFile)
    border.BottomRight:SetTexCoord(unpack(cfg.brCoords))
    border.BottomRight:ClearAllPoints()
    border.BottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cfg.brX, cfg.brY)
    border.BottomRight:SetSize(cfg.brW, cfg.brH)
    
    border.TopEdge:SetTexture(cfg.horizFile)
    border.TopEdge:SetTexCoord(unpack(cfg.teCoords))
    border.TopEdge:ClearAllPoints()
    border.TopEdge:SetPoint("TOPLEFT", border.TopLeft, "TOPRIGHT", cfg.teLeftX or 0, cfg.teY)
    border.TopEdge:SetPoint("TOPRIGHT", border.TopRight, "TOPLEFT", cfg.teRightX or 0, cfg.teY)
    border.TopEdge:SetHeight(cfg.teH)
    
    -- Bottom bar of double top header
    if border.HeaderDivider then
        border.HeaderDivider:SetTexture(cfg.horizFile)
        border.HeaderDivider:SetTexCoord(unpack(cfg.hdCoords or { 0, 1, 149/512, 157/512 }))
        border.HeaderDivider:ClearAllPoints()
        border.HeaderDivider:SetPoint("TOPLEFT", border.TopLeft, "TOPRIGHT", cfg.hdLeftX or 0, cfg.hdY or -32)
        border.HeaderDivider:SetPoint("TOPRIGHT", border.TopRight, "TOPLEFT", cfg.hdRightX or 0, cfg.hdY or -32)
        border.HeaderDivider:SetHeight(cfg.hdH or 9)
    end
    
    -- Hide TitleBg if present (master frame.Bg seamlessly covers title bar and main panel)
    if border.TitleBg then
        border.TitleBg:Hide()
    end
    
    border.BottomEdge:SetTexture(cfg.horizFile)
    border.BottomEdge:SetTexCoord(unpack(cfg.beCoords))
    border.BottomEdge:ClearAllPoints()
    border.BottomEdge:SetPoint("BOTTOMLEFT", border.BottomLeft, "BOTTOMRIGHT", cfg.beLeftX or 0, cfg.beY)
    border.BottomEdge:SetPoint("BOTTOMRIGHT", border.BottomRight, "BOTTOMLEFT", cfg.beRightX or 0, cfg.beY)
    border.BottomEdge:SetHeight(cfg.beH)
    
    border.LeftEdge:SetTexture(cfg.vertFile)
    border.LeftEdge:SetTexCoord(unpack(cfg.leCoords))
    border.LeftEdge:ClearAllPoints()
    border.LeftEdge:SetPoint("TOPLEFT", border.TopLeft, "BOTTOMLEFT", cfg.leX, cfg.leTopY or 0)
    border.LeftEdge:SetPoint("BOTTOMLEFT", border.BottomLeft, "TOPLEFT", 0, cfg.leBotY or 0)
    border.LeftEdge:SetWidth(cfg.leW)
    
    border.RightEdge:SetTexture(cfg.vertFile)
    border.RightEdge:SetTexCoord(unpack(cfg.reCoords))
    border.RightEdge:ClearAllPoints()
    border.RightEdge:SetPoint("TOPRIGHT", border.TopRight, "BOTTOMRIGHT", cfg.reX, cfg.reTopY or 0)
    border.RightEdge:SetPoint("BOTTOMRIGHT", border.BottomRight, "TOPRIGHT", 0, cfg.reBotY or 0)
    border.RightEdge:SetWidth(cfg.reW)
    
    border:Show()
    
    -- Position Player Portrait inside the gold/steel ring
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.portraitX, cfg.portraitY)
        frame.PortraitContainer:SetSize(cfg.portraitSize, cfg.portraitSize)
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
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.portraitX, cfg.portraitY)
        frame.portrait:SetSize(cfg.portraitSize, cfg.portraitSize)
        frame.portrait:Show()
    end
    
    -- Position Close Button into the beveled recess in TopRight corner
    if frame.CloseButton then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", border.TopRight, "TOPRIGHT", cfg.closeX, cfg.closeY)
        frame.CloseButton:SetFrameLevel(border:GetFrameLevel() + 5)
    end
    
    -- Position Title Text & Container inside the header slot
    local titleTarget = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText or frame.Title
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("CENTER", frame, "TOP", cfg.titleX or 0, cfg.titleY or -13)
        frame.TitleContainer:SetSize(400, 24)
        frame.TitleContainer:SetFrameLevel(border:GetFrameLevel() + 2)
        frame.TitleContainer:Show()
    end
    if titleTarget then
        titleTarget:ClearAllPoints()
        if frame.TitleContainer and titleTarget:GetParent() == frame.TitleContainer then
            titleTarget:SetPoint("CENTER", frame.TitleContainer, "CENTER", 0, 0)
        else
            titleTarget:SetPoint("CENTER", frame, "TOP", cfg.titleX or 0, cfg.titleY or -13)
        end
        titleTarget:SetDrawLayer("OVERLAY", 3)
        if titleTarget.SetJustifyH then titleTarget:SetJustifyH("CENTER") end
        if titleTarget.SetJustifyV then titleTarget:SetJustifyV("MIDDLE") end
        titleTarget:Show()
    end
    
    -- Update Character Vertical Divider if present
    local vDivider = _G["OnePanel_CharacterVerticalDivider"] or (frame and frame.CharacterVerticalDivider)
    local leftArea = _G["OnePanel_CharacterLeftArea"]
    if vDivider and leftArea and cfg.vdCoords then
        vDivider:SetTexture(cfg.vertFile)
        vDivider:SetTexCoord(unpack(cfg.vdCoords))
        vDivider:SetWidth(cfg.vdW or 7)
        vDivider:ClearAllPoints()
        vDivider:SetPoint("TOP", leftArea, "TOPRIGHT", cfg.vdX or 1, cfg.vdTopY or 11)
        vDivider:SetPoint("BOTTOM", leftArea, "BOTTOMRIGHT", cfg.vdX or 1, cfg.vdBotY or -9)
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


-------------------------------------------------------------------------------
-- Silver Tab Styling Helpers (Option A: OptionsFrame Silver/Metal BLPs)
-------------------------------------------------------------------------------

local SILVER_TAB_ACTIVE   = "Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab"
local SILVER_TAB_INACTIVE = "Interface\\OptionsFrame\\UI-OptionsFrame-InactiveTab"

--- Style an existing standard tab button (or template-based button) with Option A silver textures
-- @param button Button: The tab button to style
function FrameHelper:StyleTabAsSilver(button)
    if not button then return end
    
    local btnName = button.GetName and button:GetName()
    
    -- Inactive Textures
    local left = button.Left or (btnName and _G[btnName .. "Left"])
    local middle = button.Middle or (btnName and _G[btnName .. "Middle"])
    local right = button.Right or (btnName and _G[btnName .. "Right"])
    
    if left then
        left:SetTexture(SILVER_TAB_INACTIVE)
        left:SetTexCoord(0, 0.15625, 0, 1.0)
    end
    if middle then
        middle:SetTexture(SILVER_TAB_INACTIVE)
        middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    end
    if right then
        right:SetTexture(SILVER_TAB_INACTIVE)
        right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    end
    
    -- Active / Selected Textures
    local leftDisabled = button.LeftDisabled or (btnName and _G[btnName .. "LeftDisabled"])
    local middleDisabled = button.MiddleDisabled or (btnName and _G[btnName .. "MiddleDisabled"])
    local rightDisabled = button.RightDisabled or (btnName and _G[btnName .. "RightDisabled"])
    
    if leftDisabled then
        leftDisabled:SetTexture(SILVER_TAB_ACTIVE)
        leftDisabled:SetTexCoord(0, 0.15625, 0, 1.0)
    end
    if middleDisabled then
        middleDisabled:SetTexture(SILVER_TAB_ACTIVE)
        middleDisabled:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    end
    if rightDisabled then
        rightDisabled:SetTexture(SILVER_TAB_ACTIVE)
        rightDisabled:SetTexCoord(0.84375, 1.0, 0, 1.0)
    end
end

--- Create a standalone horizontal tab button styled with Option A silver metal textures
-- @param parent Frame: Parent frame container
-- @param name string|nil: Unique global button name
-- @param id number: Tab ID index
-- @param text string: Display text for tab label
-- @return Button: Created and styled silver tab button
function FrameHelper:CreateSilverTab(parent, name, id, text)
    local btn = CreateFrame("Button", name, parent)
    btn:SetHeight(32)
    btn:SetID(id or 1)
    
    -- Inactive state
    local left = btn:CreateTexture(name and (name .. "Left"), "BACKGROUND")
    left:SetTexture(SILVER_TAB_INACTIVE)
    left:SetSize(20, 32)
    left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -1)
    left:SetTexCoord(0, 0.15625, 0, 1.0)
    btn.Left = left
    
    local right = btn:CreateTexture(name and (name .. "Right"), "BACKGROUND")
    right:SetTexture(SILVER_TAB_INACTIVE)
    right:SetSize(20, 32)
    right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -1)
    right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    btn.Right = right
    
    local middle = btn:CreateTexture(name and (name .. "Middle"), "BACKGROUND")
    middle:SetTexture(SILVER_TAB_INACTIVE)
    middle:SetHeight(32)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    btn.Middle = middle
    
    -- Active / Selected state
    local leftDisabled = btn:CreateTexture(name and (name .. "LeftDisabled"), "BACKGROUND")
    leftDisabled:SetTexture(SILVER_TAB_ACTIVE)
    leftDisabled:SetSize(20, 35)
    leftDisabled:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 2)
    leftDisabled:SetTexCoord(0, 0.15625, 0, 1.0)
    leftDisabled:Hide()
    btn.LeftDisabled = leftDisabled
    
    local rightDisabled = btn:CreateTexture(name and (name .. "RightDisabled"), "BACKGROUND")
    rightDisabled:SetTexture(SILVER_TAB_ACTIVE)
    rightDisabled:SetSize(20, 35)
    rightDisabled:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 2)
    rightDisabled:SetTexCoord(0.84375, 1.0, 0, 1.0)
    rightDisabled:Hide()
    btn.RightDisabled = rightDisabled
    
    local middleDisabled = btn:CreateTexture(name and (name .. "MiddleDisabled"), "BACKGROUND")
    middleDisabled:SetTexture(SILVER_TAB_ACTIVE)
    middleDisabled:SetHeight(35)
    middleDisabled:SetPoint("LEFT", leftDisabled, "RIGHT", 0, 0)
    middleDisabled:SetPoint("RIGHT", rightDisabled, "LEFT", 0, 0)
    middleDisabled:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    middleDisabled:Hide()
    btn.MiddleDisabled = middleDisabled
    
    -- Highlight
    local highlight = btn:CreateTexture(name and (name .. "Highlight"), "HIGHLIGHT")
    highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, 5)
    highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 0)
    btn.Highlight = highlight
    
    -- Text Label
    local fs = btn:CreateFontString(name and (name .. "Text"), "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 2)
    fs:SetText(text or "")
    btn.Text = fs
    btn:SetFontString(fs)
    
    btn.SetSelected = function(self, selected)
        if selected then
            self.Left:Hide(); self.Middle:Hide(); self.Right:Hide()
            self.LeftDisabled:Show(); self.MiddleDisabled:Show(); self.RightDisabled:Show()
            self.Text:SetTextColor(1, 1, 1)
        else
            self.Left:Show(); self.Middle:Show(); self.Right:Show()
            self.LeftDisabled:Hide(); self.MiddleDisabled:Hide(); self.RightDisabled:Hide()
            self.Text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    return btn
end

-- Register module with Core
Utils:RegisterModule("FrameHelper", FrameHelper)

