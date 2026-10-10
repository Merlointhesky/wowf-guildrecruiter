local addonName, addonTable = ...

local ConfigFrame = CreateFrame("Frame", "GuildRecruiterConfigFrame", UIParent, "BasicFrameTemplateWithInset")
ConfigFrame:SetSize(500, 550)
ConfigFrame:SetPoint("CENTER")
ConfigFrame:SetMovable(true)
ConfigFrame:EnableMouse(true)
ConfigFrame:RegisterForDrag("LeftButton")
ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)
ConfigFrame:SetFrameStrata("DIALOG")
ConfigFrame:Hide()
tinsert(UISpecialFrames, "GuildRecruiterConfigFrame")

ConfigFrame.title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
ConfigFrame.title:SetPoint("CENTER", ConfigFrame.TitleBg, "CENTER", 5, 0)
ConfigFrame.title:SetText("Guild Recruiter Settings")

-- TABS
local activeTab = 1
local tabFrames = {}
local tabButtons = {}
local tabNames = {"Trade", "Whispers", "Responses", "Welcome", "Data"}

for i, name in ipairs(tabNames) do
    local btn = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
    btn:SetSize(80, 25)
    if i == 1 then
        btn:SetPoint("TOPLEFT", 15, -30)
    else
        btn:SetPoint("LEFT", tabButtons[i-1], "RIGHT", 5, 0)
    end
    btn:SetText(name)
    
    local content = CreateFrame("Frame", nil, ConfigFrame)
    content:SetPoint("TOPLEFT", 10, -60)
    content:SetPoint("BOTTOMRIGHT", -10, 50)
    if i > 1 then content:Hide() end
    
    btn:SetScript("OnClick", function()
        for j = 1, #tabNames do
            if j == i then
                tabFrames[j]:Show()
                tabButtons[j]:Disable()
            else
                tabFrames[j]:Hide()
                tabButtons[j]:Enable()
            end
        end
    end)
    
    table.insert(tabButtons, btn)
    table.insert(tabFrames, content)
end
tabButtons[1]:Disable() -- Initial state

local boxCampaigns = {}
local boxWhispers = {}
local boxResponses = {}

-- TAB 1: Trade Campaigns
local currentY1 = -10
local lblCampaignTitle = tabFrames[1]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblCampaignTitle:SetPoint("TOPLEFT", 10, currentY1)
lblCampaignTitle:SetText("Trade Campaign Messages (3) — max 255 chars:")
currentY1 = currentY1 - 20

for i = 1, 3 do
    local lbl = tabFrames[1]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 10, currentY1)
    lbl:SetText(i .. ".")

    local scrollContainer = CreateFrame("ScrollFrame", "GRCampaignScroll" .. i, tabFrames[1], "UIPanelScrollFrameTemplate")
    scrollContainer:SetSize(415, 60)
    scrollContainer:SetPoint("TOPLEFT", 28, currentY1 - 2)

    local bg = scrollContainer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)

    local box = CreateFrame("EditBox", nil, scrollContainer)
    box:SetMultiLine(true)
    box:SetMaxLetters(255)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(405)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollContainer:SetScrollChild(box)

    table.insert(boxCampaigns, box)
    currentY1 = currentY1 - 72
end

-- TAB 2: Whisper Templates
local currentY2 = -10
local lblWhisperTitle = tabFrames[2]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblWhisperTitle:SetPoint("TOPLEFT", 10, currentY2)
lblWhisperTitle:SetText("Whisper Templates (5):")
currentY2 = currentY2 - 20

for i = 1, 5 do
    local lbl = tabFrames[2]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 10, currentY2)
    lbl:SetText(i .. ".")

    local scrollContainer = CreateFrame("ScrollFrame", "GRWhisperScroll" .. i, tabFrames[2], "UIPanelScrollFrameTemplate")
    scrollContainer:SetSize(415, 60)
    scrollContainer:SetPoint("TOPLEFT", 28, currentY2 - 2)

    local bg = scrollContainer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)

    local box = CreateFrame("EditBox", nil, scrollContainer)
    box:SetMultiLine(true)
    box:SetMaxLetters(255)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(405)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollContainer:SetScrollChild(box)

    table.insert(boxWhispers, box)
    currentY2 = currentY2 - 72
end

-- TAB 3: Suggested Responses
local currentY3 = -10
local lblResponsesTitle = tabFrames[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblResponsesTitle:SetPoint("TOPLEFT", 10, currentY3)
lblResponsesTitle:SetText("Suggested Responses (3) — max 255 chars:")
currentY3 = currentY3 - 20

for i = 1, 3 do
    local lbl = tabFrames[3]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 10, currentY3)
    lbl:SetText(i .. ".")

    local scrollContainer = CreateFrame("ScrollFrame", "GRResponseScroll" .. i, tabFrames[3], "UIPanelScrollFrameTemplate")
    scrollContainer:SetSize(415, 60)
    scrollContainer:SetPoint("TOPLEFT", 28, currentY3 - 2)

    local bg = scrollContainer:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)

    local box = CreateFrame("EditBox", nil, scrollContainer)
    box:SetMultiLine(true)
    box:SetMaxLetters(255)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetWidth(405)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollContainer:SetScrollChild(box)

    table.insert(boxResponses, box)
    currentY3 = currentY3 - 72
end


-- TAB 4: Welcome Messages
local currentY4 = -10
local lblWelcomeTitle = tabFrames[4]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblWelcomeTitle:SetPoint("TOPLEFT", 10, currentY4)
lblWelcomeTitle:SetText("Auto-Welcome Settings:")
currentY4 = currentY4 - 20

local chkAutoWelcome = CreateFrame("CheckButton", "GR_AutoWelcomeCheck", tabFrames[4], "ChatConfigCheckButtonTemplate")
chkAutoWelcome:SetPoint("TOPLEFT", 15, currentY4)
chkAutoWelcome.Text:SetText("Enable Auto-Welcome for New Joins")
chkAutoWelcome:SetHitRectInsets(0, -chkAutoWelcome.Text:GetStringWidth() - 5, 0, 0)
currentY4 = currentY4 - 30

local lblWelcomeMsg = tabFrames[4]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblWelcomeMsg:SetPoint("TOPLEFT", 10, currentY4)
lblWelcomeMsg:SetText("Guild Chat Welcome Message (use %T for name):")
currentY4 = currentY4 - 20

local boxWelcomeMsg = CreateFrame("EditBox", "GR_WelcomeMsgBox", tabFrames[4], "InputBoxTemplate")
boxWelcomeMsg:SetSize(405, 20)
boxWelcomeMsg:SetPoint("TOPLEFT", 15, currentY4 + 5)
boxWelcomeMsg:SetAutoFocus(false)
boxWelcomeMsg:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
currentY4 = currentY4 - 20

local lblWelcomeNote = tabFrames[4]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lblWelcomeNote:SetPoint("TOPLEFT", 15, currentY4 + 5)
lblWelcomeNote:SetText("Note: You can use %T anywhere to insert their name.")
lblWelcomeNote:SetTextColor(0.5, 0.5, 0.5)
currentY4 = currentY4 - 15

local lblInfoMsg = tabFrames[4]:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblInfoMsg:SetPoint("TOPLEFT", 10, currentY4)
lblInfoMsg:SetText("Guild Info Whisper (sent directly to player, use %T for name):")
currentY4 = currentY4 - 20

local scrollInfoContainer = CreateFrame("ScrollFrame", "GRInfoScroll", tabFrames[4], "UIPanelScrollFrameTemplate")
scrollInfoContainer:SetSize(415, 60)
scrollInfoContainer:SetPoint("TOPLEFT", 28, currentY4 - 2)

local infoBg = scrollInfoContainer:CreateTexture(nil, "BACKGROUND")
infoBg:SetAllPoints()
infoBg:SetColorTexture(0, 0, 0, 0.3)

local boxInfoMsg = CreateFrame("EditBox", "GR_WelcomeInfoBox", scrollInfoContainer)
boxInfoMsg:SetMultiLine(true)
boxInfoMsg:SetMaxLetters(255)
boxInfoMsg:SetAutoFocus(false)
boxInfoMsg:SetFontObject(ChatFontNormal)
boxInfoMsg:SetWidth(405)
boxInfoMsg:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
scrollInfoContainer:SetScrollChild(boxInfoMsg)

currentY4 = currentY4 - 65
local lblInfoNote = tabFrames[4]:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
lblInfoNote:SetPoint("TOPLEFT", 15, currentY4 + 10)
lblInfoNote:SetText("Note: You can use %T anywhere to insert their name.")
lblInfoNote:SetTextColor(0.5, 0.5, 0.5)

-- TAB 5: Data & Config
local currentY5 = -10
local lblScanners = tabFrames[5]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblScanners:SetPoint("TOPLEFT", 10, currentY5)
lblScanners:SetText("Scanner Toggles:")
currentY5 = currentY5 - 20

local chkProximity = CreateFrame("CheckButton", nil, tabFrames[5], "ChatConfigCheckButtonTemplate")
chkProximity:SetPoint("TOPLEFT", 15, currentY5)
chkProximity.Text:SetText("Enable Proximity Scanner (Nameplates)")
chkProximity:SetHitRectInsets(0, -chkProximity.Text:GetStringWidth() - 5, 0, 0)
currentY5 = currentY5 - 25

local chkAutoWho = CreateFrame("CheckButton", nil, tabFrames[5], "ChatConfigCheckButtonTemplate")
chkAutoWho:SetPoint("TOPLEFT", 15, currentY5)
chkAutoWho.Text:SetText("Enable Auto-Who Scanner")
chkAutoWho:SetHitRectInsets(0, -chkAutoWho.Text:GetStringWidth() - 5, 0, 0)
currentY5 = currentY5 - 25

local chkChatParse = CreateFrame("CheckButton", nil, tabFrames[5], "ChatConfigCheckButtonTemplate")
chkChatParse:SetPoint("TOPLEFT", 15, currentY5)
chkChatParse.Text:SetText("Enable Chat Parsing (LFG/LFM keywords)")
chkChatParse:SetHitRectInsets(0, -chkChatParse.Text:GetStringWidth() - 5, 0, 0)
currentY5 = currentY5 - 25

local chkDebug = CreateFrame("CheckButton", "GR_ChkDebug", tabFrames[5], "ChatConfigCheckButtonTemplate")
chkDebug:SetPoint("TOPLEFT", 15, currentY5)
chkDebug.Text:SetText("Enable Debug Chat Output")
chkDebug:SetHitRectInsets(0, -chkDebug.Text:GetStringWidth() - 5, 0, 0)
currentY5 = currentY5 - 30

local lblChannel = tabFrames[5]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblChannel:SetPoint("TOPLEFT", 10, currentY5)
lblChannel:SetText("Broadcast Channel Number:")

local boxChannel = CreateFrame("EditBox", nil, tabFrames[5], "InputBoxTemplate")
boxChannel:SetSize(40, 20)
boxChannel:SetPoint("LEFT", lblChannel, "RIGHT", 10, 0)
boxChannel:SetAutoFocus(false)
boxChannel:SetNumeric(true)
boxChannel:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
currentY5 = currentY5 - 30

local retentionSteps = {
    {label = "5 Minutes",  value = 300},
    {label = "10 Minutes", value = 600},
    {label = "30 Minutes", value = 1800},
    {label = "1 Hour",     value = 3600},
    {label = "7 Hours",    value = 25200},
    {label = "1 Day",      value = 86400},
    {label = "3 Days",     value = 259200},
    {label = "7 Days",     value = 604800}
}

local lblRetentionTitle = tabFrames[5]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblRetentionTitle:SetPoint("TOPLEFT", 10, currentY5)
lblRetentionTitle:SetText("Data Retention:")

local sliderRetention = CreateFrame("Slider", "GuildRecruiterRetentionSlider", tabFrames[5], "OptionsSliderTemplate")
sliderRetention:SetPoint("TOPLEFT", 25, currentY5 - 25)
sliderRetention:SetWidth(370)
sliderRetention:SetMinMaxValues(1, #retentionSteps)
sliderRetention:SetValueStep(1)
sliderRetention:SetObeyStepOnDrag(true)

local lblRetentionValue = tabFrames[5]:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
lblRetentionValue:SetPoint("TOP", sliderRetention, "BOTTOM", 0, -5)

sliderRetention:SetScript("OnValueChanged", function(self, value)
    local step = math.floor(value + 0.5)
    if retentionSteps[step] then
        lblRetentionValue:SetText(retentionSteps[step].label)
    end
end)

_G[sliderRetention:GetName() .. "Low"]:SetText("5m")
_G[sliderRetention:GetName() .. "High"]:SetText("7d")

-- SAVE BUTTON (Global)
local btnSave = CreateFrame("Button", nil, ConfigFrame, "UIPanelButtonTemplate")
btnSave:SetSize(120, 30)
btnSave:SetPoint("BOTTOM", 0, 15)
btnSave:SetText("Save Settings")
btnSave:SetScript("OnClick", function()
    if not addonTable.db.Config.Templates then addonTable.db.Config.Templates = {} end
    if not addonTable.db.Config.Campaigns then addonTable.db.Config.Campaigns = {} end
    if not addonTable.db.Config.Responses then addonTable.db.Config.Responses = {} end

    for i = 1, 5 do
        local txt = boxWhispers[i]:GetText()
        addonTable.db.Config.Templates[i] = (txt ~= "") and txt or nil
    end

    for i = 1, 3 do
        local txt = boxCampaigns[i]:GetText()
        addonTable.db.Config.Campaigns[i] = (txt ~= "") and txt or nil
    end

    for i = 1, 3 do
        local txt = boxResponses[i]:GetText()
        addonTable.db.Config.Responses[i] = (txt ~= "") and txt or nil
    end

    addonTable.db.Config.EnableAutoWelcome = GR_AutoWelcomeCheck:GetChecked()
    addonTable.db.Config.WelcomeMessage = GR_WelcomeMsgBox:GetText()
    addonTable.db.Config.WelcomeInfoMessage = GR_WelcomeInfoBox:GetText()

    addonTable.db.Config.EnableAutoScanner = chkProximity:GetChecked()
    addonTable.db.Config.EnableAutoWho = chkAutoWho:GetChecked()
    addonTable.db.Config.EnableChatParser = chkChatParse:GetChecked()
    addonTable.db.Config.EnableDebug = GR_ChkDebug:GetChecked()

    local ch = tonumber(boxChannel:GetText())
    if ch then addonTable.db.Config.BroadcastChannel = ch end

    local step = math.floor(sliderRetention:GetValue() + 0.5)
    if retentionSteps[step] then
        addonTable.db.Config.RetentionTime = retentionSteps[step].value
    end

    print("|cFF00FF00[Guild Recruiter]|r Settings saved!")
    ConfigFrame:Hide()
end)

ConfigFrame:SetScript("OnShow", function()
    local templates = addonTable.db.Config.Templates or {}
    for i = 1, 5 do boxWhispers[i]:SetText(templates[i] or "") end

    local campaigns = addonTable.db.Config.Campaigns or {}
    for i = 1, 3 do boxCampaigns[i]:SetText(campaigns[i] or "") end

    local responses = addonTable.db.Config.Responses or {}
    for i = 1, 3 do boxResponses[i]:SetText(responses[i] or "") end

    GR_AutoWelcomeCheck:SetChecked(addonTable.db.Config.EnableAutoWelcome ~= false)
    GR_WelcomeMsgBox:SetText(addonTable.db.Config.WelcomeMessage or "")
    GR_WelcomeInfoBox:SetText(addonTable.db.Config.WelcomeInfoMessage or "")

    chkProximity:SetChecked(addonTable.db.Config.EnableAutoScanner ~= false)
    chkAutoWho:SetChecked(addonTable.db.Config.EnableAutoWho ~= false)
    chkChatParse:SetChecked(addonTable.db.Config.EnableChatParser ~= false)
    GR_ChkDebug:SetChecked(addonTable.db.Config.EnableDebug == true)

    boxChannel:SetText(tostring(addonTable.db.Config.BroadcastChannel or 2))

    local currentRetention = addonTable.db.Config.RetentionTime or 86400
    local targetStep = 6
    for i, stepInfo in ipairs(retentionSteps) do
        if stepInfo.value == currentRetention then
            targetStep = i
            break
        end
    end
    sliderRetention:SetValue(targetStep)
    lblRetentionValue:SetText(retentionSteps[targetStep].label)
end)

function addonTable.ToggleConfigWindow()
    if ConfigFrame:IsShown() then
        ConfigFrame:Hide()
    else
        ConfigFrame:Show()
    end
end
