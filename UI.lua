local addonName, addonTable = ...
local UI = {}
addonTable.UI = UI

-- Main CRM Window
local MainFrame = CreateFrame("Frame", "GuildRecruiterMainFrame", UIParent, "BasicFrameTemplateWithInset")
MainFrame:SetSize(850, 550) -- Default size
MainFrame:SetPoint("CENTER")
MainFrame:SetMovable(true)
MainFrame:SetResizable(true)
MainFrame:EnableMouse(true)
MainFrame:RegisterForDrag("LeftButton")
MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
MainFrame:Hide()
tinsert(UISpecialFrames, "GuildRecruiterMainFrame")

MainFrame:HookScript("OnShow", function(self)
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    if screenWidth and screenHeight and screenWidth > 0 then
        local frameWidth = math.min(1200, math.max(850, screenWidth * 0.75))
        local frameHeight = math.min(800, math.max(550, screenHeight * 0.75))
        self:SetSize(frameWidth, frameHeight)
    end
end)

MainFrame.title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
MainFrame.title:SetPoint("CENTER", MainFrame.TitleBg, "CENTER", 5, 0)
MainFrame.title:SetText("Guild Recruiter CRM")

-- Toggle Function
function addonTable.ToggleMainWindow()
    if MainFrame:IsShown() then
        MainFrame:Hide()
    else
        MainFrame:Show()
    end
end

-- Minimap Button
local MinimapButton = CreateFrame("Button", "GuildRecruiterMinimapBtn", Minimap)
MinimapButton:SetSize(32, 32)
MinimapButton:SetFrameStrata("MEDIUM")
MinimapButton:SetFrameLevel(8)
MinimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)

local iconTexture = MinimapButton:CreateTexture(nil, "BACKGROUND")
iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
iconTexture:SetSize(21, 21)
iconTexture:SetPoint("CENTER", MinimapButton, "CENTER", 0, 0)

local borderTexture = MinimapButton:CreateTexture(nil, "OVERLAY")
borderTexture:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
borderTexture:SetSize(54, 54)
borderTexture:SetPoint("TOPLEFT", MinimapButton, "TOPLEFT", 0, 0)

MinimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

-- Mouse Interactions for Minimap
MinimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
MinimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        addonTable.ToggleMainWindow()
    elseif button == "RightButton" then
        if addonTable.ToggleConfigWindow then
            addonTable.ToggleConfigWindow()
        end
    end
end)

MinimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Guild Recruiter")
    GameTooltip:AddLine("Left-Click: Open CRM", 1, 1, 1)
    GameTooltip:AddLine("Right-Click: Open Settings", 1, 1, 1)
    GameTooltip:AddLine(" ")
    -- Live Session Stats from Communications.lua
    local stats = addonTable.SessionStats or {}
    GameTooltip:AddDoubleLine("Whispers Sent:", tostring(stats.whispersSent or 0), 1, 0.8, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Responses:", tostring(stats.responses or 0), 1, 0.8, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Guild Joins (Total):", tostring(stats.totalJoined or 0), 1, 0.8, 0, 0, 1, 0)
    GameTooltip:AddDoubleLine("Guild Joins (Yours):", tostring(stats.invitedJoined or 0), 1, 0.8, 0, 0, 1, 0)
    GameTooltip:Show()
end)

MinimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-- Visual Flash function for when a whisper is intercepted
local isFlashing = false
local flashTimer = 0
function addonTable.FlashMinimap(self, elapsed)
    if self.isDragging then
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx, dy = (xpos / scale) - cx, (ypos / scale) - cy
        
        local angle = math.atan2(dy, dx)
        -- Dynamic radius based on minimap and button size
        local radius = (Minimap:GetWidth() / 2) + (self:GetWidth() / 3)
        
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end

    if not isFlashing then return end
    flashTimer = flashTimer + elapsed
    local alpha = (math.sin(flashTimer * 5) + 1) / 2
    iconTexture:SetAlpha(0.2 + (alpha * 0.8))
end

MinimapButton:SetMovable(true)
MinimapButton:RegisterForDrag("LeftButton")
MinimapButton:SetScript("OnDragStart", function(self) self.isDragging = true end)
MinimapButton:SetScript("OnDragStop", function(self) 
    self.isDragging = false
    if type(GuildRecruiterDB) == "table" then
        local xpos, ypos = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx, dy = (xpos / scale) - cx, (ypos / scale) - cy
        GuildRecruiterDB.minimapAngle = math.atan2(dy, dx)
    end
end)
MinimapButton:SetScript("OnUpdate", addonTable.FlashMinimap)

function addonTable.LoadMinimapPosition()
    if type(GuildRecruiterDB) == "table" and GuildRecruiterDB.minimapAngle then
        local angle = GuildRecruiterDB.minimapAngle
        local radius = (Minimap:GetWidth() / 2) + (MinimapButton:GetWidth() / 3)
        MinimapButton:ClearAllPoints()
        MinimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    end
end

function addonTable.TriggerMinimapFlash()
    isFlashing = true
    flashTimer = 0
end

function addonTable.StopMinimapFlash()
    isFlashing = false
    iconTexture:SetAlpha(1)
end
