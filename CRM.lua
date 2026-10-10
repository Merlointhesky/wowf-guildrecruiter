local addonName, addonTable = ...
local CRM = {}
addonTable.CRM = CRM

local MainFrame = GuildRecruiterMainFrame

---------------------------------------------------------------------------
-- TAB SYSTEM
---------------------------------------------------------------------------
local TAB_SEARCH = 1
local TAB_CANDIDATES = 2
local TAB_MEMBERS = 3
local activeTab = TAB_SEARCH

local SearchContent = CreateFrame("Frame", nil, MainFrame)
SearchContent:SetPoint("TOPLEFT", 10, -30)
SearchContent:SetPoint("BOTTOMRIGHT", -10, 10)

local CandidatesContent = CreateFrame("Frame", nil, MainFrame)
CandidatesContent:SetPoint("TOPLEFT", 10, -30)
CandidatesContent:SetPoint("BOTTOMRIGHT", -10, 10)
CandidatesContent:Hide()

local MembersContent = CreateFrame("Frame", nil, MainFrame)
MembersContent:SetPoint("TOPLEFT", 10, -30)
MembersContent:SetPoint("BOTTOMRIGHT", -10, 10)
MembersContent:Hide()

local btnTabSearch = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
btnTabSearch:SetSize(120, 25)
btnTabSearch:SetPoint("TOPLEFT", 15, -2)
btnTabSearch:SetText("Search")

local btnTabCandidates = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
btnTabCandidates:SetSize(120, 25)
btnTabCandidates:SetPoint("LEFT", btnTabSearch, "RIGHT", 5, 0)
btnTabCandidates:SetText("Candidates")

local btnTabMembers = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
btnTabMembers:SetSize(120, 25)
btnTabMembers:SetPoint("LEFT", btnTabCandidates, "RIGHT", 5, 0)
btnTabMembers:SetText("Members")

local function SetActiveTab(tabID)
    activeTab = tabID
    SearchContent:Hide()
    CandidatesContent:Hide()
    MembersContent:Hide()
    btnTabSearch:Enable()
    btnTabCandidates:Enable()
    btnTabMembers:Enable()

    if tabID == TAB_SEARCH then
        SearchContent:Show()
        btnTabSearch:Disable()
        CRM.UpdateSearchResults()
    elseif tabID == TAB_CANDIDATES then
        CandidatesContent:Show()
        btnTabCandidates:Disable()
        CRM.UpdateCandidateList()
    elseif tabID == TAB_MEMBERS then
        MembersContent:Show()
        btnTabMembers:Disable()
        if CRM.UpdateMembersList then CRM.UpdateMembersList() end
    end
end

btnTabSearch:SetScript("OnClick", function() SetActiveTab(TAB_SEARCH) end)
btnTabCandidates:SetScript("OnClick", function() SetActiveTab(TAB_CANDIDATES) end)
btnTabMembers:SetScript("OnClick", function() SetActiveTab(TAB_MEMBERS) end)

---------------------------------------------------------------------------
-- SEARCH TAB
---------------------------------------------------------------------------
-- Row 1 (Y=0): Search box, Search button, Unguilded toggle, Proactive scan
local row1Y = -5

function addonTable.ClearNewLeads()
    if addonTable.db and addonTable.db.Leads then
        for name, data in pairs(addonTable.db.Leads) do
            if data.status == "New" then
                addonTable.db.Leads[name] = nil
            end
        end
    end
    if CRM.UpdateSearchResults then CRM.UpdateSearchResults() end
end

local function GetManualSearchQuery(q)
    local builtQuery = ""
    if q and strtrim(q) ~= "" then
        builtQuery = strtrim(q) .. " "
    end
    
    local minLvl = addonTable.db.Config.FilterMinLevel or ""
    local maxLvl = addonTable.db.Config.FilterMaxLevel or ""
    local levels = ""
    if minLvl ~= "" and maxLvl ~= "" then levels = minLvl .. "-" .. maxLvl
    elseif minLvl ~= "" then levels = minLvl
    elseif maxLvl ~= "" then levels = maxLvl end
    
    if levels ~= "" then builtQuery = builtQuery .. levels .. " " end
    
    return strtrim(builtQuery)
end

local SearchBox = CreateFrame("EditBox", nil, SearchContent, "InputBoxTemplate")
SearchBox:SetSize(150, 20)
SearchBox:SetPoint("TOPLEFT", 10, row1Y)
SearchBox:SetAutoFocus(false)
SearchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local q = GetManualSearchQuery(self:GetText())
    addonTable.ClearNewLeads()
    addonTable.ExecuteWhoSearch(q) 
end)

local btnSearch = CreateFrame("Button", nil, SearchContent, "UIPanelButtonTemplate")
btnSearch:SetSize(70, 25)
btnSearch:SetPoint("LEFT", SearchBox, "RIGHT", 5, 0)
btnSearch:SetText("Search")
btnSearch:SetScript("OnClick", function()
    SearchBox:ClearFocus()
    local q = GetManualSearchQuery(SearchBox:GetText())
    addonTable.ClearNewLeads()
    addonTable.ExecuteWhoSearch(q) 
end)

local chkUnguilded = CreateFrame("CheckButton", nil, SearchContent, "ChatConfigCheckButtonTemplate")
chkUnguilded:SetPoint("LEFT", btnSearch, "RIGHT", 15, 0)
chkUnguilded.Text:SetText("Unguilded")
chkUnguilded:SetHitRectInsets(0, -chkUnguilded.Text:GetStringWidth() - 5, 0, 0)
chkUnguilded:SetScript("OnShow", function(self) self:SetChecked(addonTable.db.Config.FilterGuilded ~= false) end)
chkUnguilded:SetScript("OnClick", function(self) addonTable.db.Config.FilterGuilded = self:GetChecked() end)

local chkOnlyNew = CreateFrame("CheckButton", nil, SearchContent, "ChatConfigCheckButtonTemplate")
chkOnlyNew:SetPoint("LEFT", chkUnguilded.Text, "RIGHT", 15, 0)
chkOnlyNew.Text:SetText("Only New")
chkOnlyNew:SetHitRectInsets(0, -chkOnlyNew.Text:GetStringWidth() - 5, 0, 0)
chkOnlyNew:SetScript("OnShow", function(self) self:SetChecked(addonTable.db.Config.FilterOnlyNew ~= false) end)
chkOnlyNew:SetScript("OnClick", function(self) 
    addonTable.db.Config.FilterOnlyNew = self:GetChecked()
    CRM.UpdateSearchResults()
end)

local isScanningActive = false
local btnStartScan = CreateFrame("Button", nil, SearchContent, "UIPanelButtonTemplate")
btnStartScan:SetSize(165, 25)
btnStartScan:SetPoint("LEFT", chkOnlyNew.Text, "RIGHT", 20, 0)
btnStartScan:SetText("Start Proactive Scan")

local function UpdateScanButtonText()
    if isScanningActive then
        local queueCount, remaining = addonTable.AdvanceProactiveScan and addonTable.AdvanceProactiveScan(true) or 0, addonTable.GetWhoCooldownRemaining and addonTable.GetWhoCooldownRemaining() or 0
        if queueCount == 0 then
            isScanningActive = false
            btnStartScan:SetText("Start Proactive Scan")
            btnStartScan:Enable()
        else
            if remaining > 0 then
                btnStartScan:SetText("Wait " .. remaining .. "s (" .. queueCount .. " left)")
                btnStartScan:Disable()
            else
                btnStartScan:SetText("Next Scan (" .. queueCount .. " left)")
                btnStartScan:Enable()
            end
        end
    else
        local remaining = addonTable.GetWhoCooldownRemaining and addonTable.GetWhoCooldownRemaining() or 0
        if remaining > 0 then
            btnStartScan:SetText("Wait " .. remaining .. "s")
            btnStartScan:Disable()
        else
            btnStartScan:SetText("Start Proactive Scan")
            btnStartScan:Enable()
        end
    end
end

btnStartScan:SetScript("OnUpdate", function(self, elapsed)
    self.timer = (self.timer or 0) + elapsed
    if self.timer >= 1.0 then
        self.timer = 0
        UpdateScanButtonText()
    end
end)

btnStartScan:SetScript("OnClick", function(self)
    if isScanningActive then
        addonTable.AdvanceProactiveScan()
    else
        isScanningActive = true
        if addonTable.StartProactiveScan then addonTable.StartProactiveScan() end
        addonTable.AdvanceProactiveScan()
    end
    UpdateScanButtonText()
end)

-- Row 2 (Y=-28): Level range
local row2Y = row1Y - 28
local lblLevels = SearchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblLevels:SetPoint("TOPLEFT", 10, row2Y)
lblLevels:SetText("Levels:")
lblLevels:SetTextColor(1, 0.82, 0)

local boxMinLevel = CreateFrame("EditBox", nil, SearchContent, "InputBoxTemplate")
boxMinLevel:SetSize(40, 20)
boxMinLevel:SetPoint("LEFT", lblLevels, "RIGHT", 5, 0)
boxMinLevel:SetAutoFocus(false)
boxMinLevel:SetNumeric(true)
boxMinLevel:SetMaxLetters(2)
boxMinLevel:SetScript("OnShow", function(self) self:SetText(addonTable.db.Config.FilterMinLevel or "") end)
boxMinLevel:SetScript("OnTextChanged", function(self) addonTable.db.Config.FilterMinLevel = self:GetText() end)
boxMinLevel:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local lblTo = SearchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblTo:SetPoint("LEFT", boxMinLevel, "RIGHT", 5, 0)
lblTo:SetText("-")

local boxMaxLevel = CreateFrame("EditBox", nil, SearchContent, "InputBoxTemplate")
boxMaxLevel:SetSize(40, 20)
boxMaxLevel:SetPoint("LEFT", lblTo, "RIGHT", 5, 0)
boxMaxLevel:SetAutoFocus(false)
boxMaxLevel:SetNumeric(true)
boxMaxLevel:SetMaxLetters(2)
boxMaxLevel:SetScript("OnShow", function(self) self:SetText(addonTable.db.Config.FilterMaxLevel or "") end)
boxMaxLevel:SetScript("OnTextChanged", function(self) addonTable.db.Config.FilterMaxLevel = self:GetText() end)
boxMaxLevel:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- Row 3 (Y=-50): Class checkboxes (all 9 classes, both factions)
local row3Y = row2Y - 22
local lblClasses = SearchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblClasses:SetPoint("TOPLEFT", 10, row3Y)
lblClasses:SetText("Classes:")
lblClasses:SetTextColor(1, 0.82, 0)

local ALL_CLASSES = {"Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid"}
local classChecks = {}
local classX = 65
for _, className in ipairs(ALL_CLASSES) do
    local chk = CreateFrame("CheckButton", nil, SearchContent, "UICheckButtonTemplate")
    chk:SetPoint("TOPLEFT", classX, row3Y + 5)
    chk:SetSize(24, 24)
    chk:SetChecked(false)
    
    local lbl = chk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", chk, "RIGHT", -2, 0)
    lbl:SetText(className)
    
    -- Increase hit rect to include the text
    chk:SetHitRectInsets(0, -lbl:GetStringWidth() - 2, 0, 0)
    
    classChecks[className] = chk
    classX = classX + 24 + lbl:GetStringWidth() + 15
end

-- Row 4 (Y=-72): Race checkboxes (faction-dependent)
local row4Y = row3Y - 22
local lblRaces = SearchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblRaces:SetPoint("TOPLEFT", 10, row4Y)
lblRaces:SetText("Races:")
lblRaces:SetTextColor(1, 0.82, 0)

local RACES = {
    Alliance = {"Human", "Dwarf", "Night Elf", "Gnome", "Skyborne"},
    Horde = {"Orc", "Undead", "Tauren", "Troll", "Skyborne"}
}
local raceChecks = {}
local raceCheckFrames = {}
local raceX = 65
for i = 1, 5 do
    local chk = CreateFrame("CheckButton", nil, SearchContent, "UICheckButtonTemplate")
    chk:SetPoint("TOPLEFT", raceX, row4Y + 5)
    chk:SetSize(24, 24)
    chk:SetChecked(false)
    
    local lbl = chk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", chk, "RIGHT", -2, 0)
    lbl:SetText("")
    chk.label = lbl
    
    table.insert(raceCheckFrames, chk)
    raceX = raceX + 90
end

-- Populate race labels on show based on player faction
SearchContent:SetScript("OnShow", function()
    local faction = UnitFactionGroup("player")
    local myRaces = RACES[faction] or RACES.Alliance
    raceChecks = {}
    
    local currentX = 65
    for i, raceName in ipairs(myRaces) do
        if raceCheckFrames[i] then
            raceCheckFrames[i].label:SetText(raceName)
            raceCheckFrames[i]:SetHitRectInsets(0, -raceCheckFrames[i].label:GetStringWidth() - 2, 0, 0)
            raceCheckFrames[i]:SetPoint("TOPLEFT", currentX, row4Y + 5)
            raceCheckFrames[i]:Show()
            raceChecks[raceName] = raceCheckFrames[i]
            
            currentX = currentX + 24 + raceCheckFrames[i].label:GetStringWidth() + 15
        end
    end
    for i = #myRaces + 1, #raceCheckFrames do
        raceCheckFrames[i]:Hide()
    end
end)

-- Helpers for Scanner to read checked filters
function addonTable.GetCheckedClasses()
    local result = {}
    for className, chk in pairs(classChecks) do
        if chk:GetChecked() then table.insert(result, className) end
    end
    return result
end

function addonTable.GetCheckedRaces()
    local result = {}
    for raceName, chk in pairs(raceChecks) do
        if chk:GetChecked() then table.insert(result, raceName) end
    end
    return result
end

-- Row 5 (Y=-94): Status label
local row5Y = row4Y - 22
local lblSearchStatus = SearchContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblSearchStatus:SetPoint("TOPLEFT", 10, row5Y)
lblSearchStatus:SetTextColor(0, 0.8, 1)
lblSearchStatus:SetText("Ready.")

function addonTable.SetSearchStatus(text)
    lblSearchStatus:SetText(text)
end

-- Row 6 (Y=-110): Column headers
local row6Y = row5Y - 16
local searchHeaders = CreateFrame("Frame", nil, SearchContent)
searchHeaders:SetSize(750, 16)
searchHeaders:SetPoint("TOPLEFT", 5, row6Y)

local searchSortCol = "name"
local searchSortAsc = true

local headerNames = {"Name", "Level", "Class", "Actions", "Status"}
local headerKeys = {"name", "level", "class", nil, "status"}
local headerWidths = {130, 50, 80, 280, 180}
local headerX = 10
for i, hName in ipairs(headerNames) do
    if headerKeys[i] then
        local btn = CreateFrame("Button", nil, searchHeaders)
        btn:SetSize(headerWidths[i], 16)
        btn:SetPoint("LEFT", headerX, 0)
        local h = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", 0, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
        btn:SetScript("OnClick", function()
            if searchSortCol == headerKeys[i] then
                searchSortAsc = not searchSortAsc
            else
                searchSortCol = headerKeys[i]
                searchSortAsc = true
            end
            CRM.UpdateSearchResults()
        end)
    else
        local h = searchHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", headerX, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
    end
    headerX = headerX + headerWidths[i]
end

-- Scrollable results list
local SearchScroll = CreateFrame("ScrollFrame", "GRSearchScrollFrame", SearchContent, "UIPanelScrollFrameTemplate")
SearchScroll:SetPoint("TOPLEFT", 5, row6Y - 16)
SearchScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local SearchScrollChild = CreateFrame("Frame")
SearchScrollChild:SetSize(1, 1)
SearchScroll:SetScrollChild(SearchScrollChild)

local searchRows = {}
local SEARCH_ROW_HEIGHT = 28

local function CreateSearchRow(index)
    local row = CreateFrame("Frame", nil, SearchScrollChild)
    row:SetSize(750, SEARCH_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * SEARCH_ROW_HEIGHT))

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 10, 0); row.nameText:SetWidth(120); row.nameText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.levelText:SetPoint("LEFT", 140, 0); row.levelText:SetWidth(40); row.levelText:SetJustifyH("LEFT")

    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.classText:SetPoint("LEFT", 190, 0); row.classText:SetWidth(70); row.classText:SetJustifyH("LEFT")

    row.btnTemplate = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.btnTemplate:SetSize(80, 20); row.btnTemplate:SetPoint("LEFT", 270, 0)
    row.btnTemplate:SetText("Whisper >>")
    row.btnTemplate:SetScript("OnClick", function(self)
        if row.playerName then addonTable.ShowTemplateMenu(self, row.playerName) end
    end)

    row.btnBlacklist = CreateFrame("Button", nil, row)
    row.btnBlacklist:SetSize(22, 22); row.btnBlacklist:SetPoint("LEFT", row.btnTemplate, "RIGHT", 5, 0)
    row.btnBlacklist:SetNormalTexture("Interface\\Icons\\INV_Misc_Bone_Skull_02")
    row.btnBlacklist:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnBlacklist:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Block (Blacklist)"); GameTooltip:Show() end)
    row.btnBlacklist:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnBlacklist:SetScript("OnClick", function()
        if row.playerName then
            addonTable.db.Leads[row.playerName].status = "Blacklisted"
            addonTable.db.Blacklist[row.playerName] = true
            CRM.UpdateSearchResults()
        end
    end)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", row.btnBlacklist, "RIGHT", 15, 0); row.statusText:SetWidth(180); row.statusText:SetJustifyH("LEFT")

    return row
end

function CRM.UpdateSearchResults()
    for _, row in ipairs(searchRows) do row:Hide() end

    local index = 1
    local totalHeight = 0

    local sortedNames = {}
    if addonTable.db and addonTable.db.Leads then
        local onlyNew = addonTable.db.Config.FilterOnlyNew ~= false
        for name, data in pairs(addonTable.db.Leads) do
            local isRecent = addonTable.RecentSearchResults and addonTable.RecentSearchResults[name]
            local isNew = (data.status == "New")
            
            if onlyNew then
                if isNew then table.insert(sortedNames, name) end
            else
                if isNew or isRecent then table.insert(sortedNames, name) end
            end
        end
        
        table.sort(sortedNames, function(a, b)
            local dataA = addonTable.db.Leads[a]
            local dataB = addonTable.db.Leads[b]
            local valA, valB
            
            if searchSortCol == "level" then
                valA = tonumber(dataA.level) or 0
                valB = tonumber(dataB.level) or 0
            elseif searchSortCol == "class" then
                valA = tostring(dataA.class or "")
                valB = tostring(dataB.class or "")
            elseif searchSortCol == "status" then
                valA = dataA.status or ""
                valB = dataB.status or ""
            else
                valA = a
                valB = b
            end
            
            if searchSortAsc then
                return valA < valB
            else
                return valA > valB
            end
        end)
        
        for _, name in ipairs(sortedNames) do
            local data = addonTable.db.Leads[name]
            local row = searchRows[index]
            if not row then
                row = CreateSearchRow(index)
                table.insert(searchRows, row)
            end

            row.playerName = name
            row.nameText:SetText(name)
            local c = RAID_CLASS_COLORS[string.upper(tostring(data.class or ""))]
            if c then row.nameText:SetTextColor(c.r, c.g, c.b)
            else row.nameText:SetTextColor(1, 1, 1) end

            row.levelText:SetText(tostring(data.level or "?"))
            row.classText:SetText(data.class or "?")

            local status = data.status or "New"
            local displayStatus = status
            if data.claimedBy and data.claimedBy ~= UnitName("player") then
                displayStatus = status .. "\n|cFF888888(" .. data.claimedBy .. ")|r"
            end
            row.statusText:SetText(displayStatus)
            if status == "Joined" then row.statusText:SetTextColor(0, 1, 0)
            elseif status == "Interviewing" then row.statusText:SetTextColor(1, 0.8, 0)
            elseif status == "Pitched" then row.statusText:SetTextColor(0.6, 0.8, 1)
            else row.statusText:SetTextColor(1, 1, 1) end

            row:Show()
            index = index + 1
            totalHeight = totalHeight + SEARCH_ROW_HEIGHT
        end
    end
    SearchScrollChild:SetHeight(math.max(totalHeight, 1))
end

-- Bottom bar for Search tab
local searchBottom = CreateFrame("Frame", nil, SearchContent)
searchBottom:SetSize(800, 30)
searchBottom:SetPoint("BOTTOMLEFT", 0, 5)

local btnClearSearch = CreateFrame("Button", nil, searchBottom, "UIPanelButtonTemplate")
btnClearSearch:SetSize(100, 25); btnClearSearch:SetPoint("LEFT", 10, 0)
btnClearSearch:SetText("Clear")
btnClearSearch:SetScript("OnClick", function()
    addonTable.ClearNewLeads()
    addonTable.SetSearchStatus("Search results cleared.")
end)

local btnResetFilters = CreateFrame("Button", nil, searchBottom, "UIPanelButtonTemplate")
btnResetFilters:SetSize(100, 25); btnResetFilters:SetPoint("LEFT", btnClearSearch, "RIGHT", 10, 0)
btnResetFilters:SetText("Reset Filters")
btnResetFilters:SetScript("OnClick", function()
    addonTable.db.Config.FilterMinLevel = ""
    addonTable.db.Config.FilterMaxLevel = ""
    boxMinLevel:SetText("")
    boxMaxLevel:SetText("")
    for _, chk in pairs(classChecks) do chk:SetChecked(false) end
    for _, chk in pairs(raceChecks) do chk:SetChecked(false) end
    SearchBox:SetText("")
end)

local btnBulkPitch = CreateFrame("Button", nil, searchBottom, "UIPanelButtonTemplate")
btnBulkPitch:SetSize(150, 25); btnBulkPitch:SetPoint("LEFT", btnResetFilters, "RIGHT", 10, 0)
btnBulkPitch:SetText("Bulk Whisper 'New'")
btnBulkPitch:SetScript("OnClick", function()
    local templates = addonTable.db.Config.Templates or {}
    local validTemplates = {}
    for _, t in ipairs(templates) do
        if t and t ~= "" then table.insert(validTemplates, t) end
    end
    if #validTemplates == 0 then table.insert(validTemplates, "Hey! Looking for a guild?") end
    
    local tIndex = 1
    for name, data in pairs(addonTable.db.Leads) do
        if data.status == "New" then
            addonTable.QueueBulkWhisper(name, validTemplates[tIndex])
            data.status = "Pitched"
            data.claimedBy = UnitName("player")
            if addonTable.SyncStatus then
                addonTable.SyncStatus(name, "Pitched")
            end
            tIndex = tIndex + 1
            if tIndex > #validTemplates then tIndex = 1 end
        end
    end
    CRM.UpdateSearchResults()
end)

local btnBroadcast = CreateFrame("Button", nil, searchBottom, "UIPanelButtonTemplate")
btnBroadcast:SetSize(150, 25); btnBroadcast:SetPoint("LEFT", btnBulkPitch, "RIGHT", 10, 0)
btnBroadcast:SetText("Broadcast to Trade")
btnBroadcast:SetScript("OnClick", function()
    if addonTable.BroadcastCampaign then addonTable.BroadcastCampaign() end
end)

---------------------------------------------------------------------------
-- CANDIDATES TAB
---------------------------------------------------------------------------
local candHeaders = CreateFrame("Frame", nil, CandidatesContent)
candHeaders:SetSize(800, 20)
candHeaders:SetPoint("TOPLEFT", 5, -5)

local candSortCol = "name"
local candSortAsc = true

local candHeaderNames = {"Name", "Lvl", "Class", "Notes", "Actions", "Status"}
local candHeaderKeys = {"name", "level", "class", "notes", nil, "status"}
local candHeaderWidths = {110, 35, 70, 160, 270, 150}
local candHeaderX = 10
for i, hName in ipairs(candHeaderNames) do
    if candHeaderKeys[i] then
        local btn = CreateFrame("Button", nil, candHeaders)
        btn:SetSize(candHeaderWidths[i], 16)
        btn:SetPoint("LEFT", candHeaderX, 0)
        local h = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", 0, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
        btn:SetScript("OnClick", function()
            if candSortCol == candHeaderKeys[i] then
                candSortAsc = not candSortAsc
            else
                candSortCol = candHeaderKeys[i]
                candSortAsc = true
            end
            CRM.UpdateCandidateList()
        end)
    else
        local h = candHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", candHeaderX, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
    end
    candHeaderX = candHeaderX + candHeaderWidths[i]
end

local CandScroll = CreateFrame("ScrollFrame", "GRCandidatesScrollFrame", CandidatesContent, "UIPanelScrollFrameTemplate")
CandScroll:SetPoint("TOPLEFT", 5, -25)
CandScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local CandScrollChild = CreateFrame("Frame")
CandScrollChild:SetSize(1, 1)
CandScroll:SetScrollChild(CandScrollChild)

local candidateRows = {}
local CAND_ROW_HEIGHT = 28

---------------------------------------------------------------------------
-- WHISPER HISTORY UI
---------------------------------------------------------------------------
local historyFramePool = {}
local activeHistoryFrames = {}
local historyFrameCounter = 0

local function CreateHistoryFrame()
    historyFrameCounter = historyFrameCounter + 1
    local frame = CreateFrame("Frame", "GRHistoryFrame" .. historyFrameCounter, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(540, 300)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetToplevel(true)
    frame.TitleText:SetText("Whisper History")
    
    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -30, 45)
    local textFrame = CreateFrame("Frame", nil, scroll)
    textFrame:SetSize(340, 1)
    scroll:SetScrollChild(textFrame)
    
    local fontString = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fontString:SetPoint("TOPLEFT", 0, 0)
    fontString:SetWidth(340)
    fontString:SetJustifyH("LEFT")
    fontString:SetJustifyV("TOP")
    
    local input = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    input:SetSize(230, 20)
    input:SetPoint("BOTTOMLEFT", 15, 12)
    input:SetAutoFocus(false)
    
    local sendBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    sendBtn:SetSize(55, 25)
    sendBtn:SetPoint("LEFT", input, "RIGHT", 5, 0)
    sendBtn:SetText("Send")
    
    local respBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    respBtn:SetSize(85, 25)
    respBtn:SetPoint("LEFT", sendBtn, "RIGHT", 5, 0)
    respBtn:SetText("Responses >>")
    respBtn:SetScript("OnClick", function(self)
        if frame.playerName then
            addonTable.ShowResponseMenu(self, frame.playerName)
        end
    end)
    
    local inviteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    inviteBtn:SetSize(60, 25)
    inviteBtn:SetPoint("LEFT", respBtn, "RIGHT", 5, 0)
    inviteBtn:SetText("Invite")
    inviteBtn:SetScript("OnClick", function()
        if frame.playerName then
            if frame.context == "member" then
                if C_PartyInfo and C_PartyInfo.InviteUnit then
                    C_PartyInfo.InviteUnit(frame.playerName)
                else
                    InviteUnit(frame.playerName)
                end
            elseif addonTable.InviteLead then
                addonTable.InviteLead(frame.playerName)
            end
        end
    end)
    
    local blockBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    blockBtn:SetSize(60, 25)
    blockBtn:SetPoint("LEFT", inviteBtn, "RIGHT", 5, 0)
    blockBtn:SetText("Block")
    blockBtn:SetScript("OnClick", function()
        if frame.playerName then
            addonTable.db.Leads[frame.playerName].status = "Blacklisted"
            addonTable.db.Blacklist[frame.playerName] = true
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
            frame:Hide()
        end
    end)
    
    local function SendMsg()
        local msg = input:GetText()
        if msg and msg ~= "" and frame.playerName then
            SendChatMessage(msg, "WHISPER", nil, frame.playerName)
            input:SetText("")
        end
        input:ClearFocus()
    end
    input:SetScript("OnEnterPressed", SendMsg)
    sendBtn:SetScript("OnClick", SendMsg)
    
    frame.scroll = scroll
    frame.textFrame = textFrame
    frame.historyText = fontString
    frame.input = input
    frame.sendBtn = sendBtn
    frame.respBtn = respBtn
    frame.inviteBtn = inviteBtn
    frame.blockBtn = blockBtn
    
    table.insert(UISpecialFrames, frame:GetName())
    
    return frame
end

function addonTable.UpdateHistoryIfOpen(playerName)
    local frame = activeHistoryFrames[playerName]
    if frame and frame:IsShown() then
        addonTable.ShowHistory(playerName, frame.context)
    end
end

function addonTable.ShowHistory(playerName, context)
    local frame = activeHistoryFrames[playerName]
    if not frame then
        for _, f in ipairs(historyFramePool) do
            if not f:IsShown() then
                frame = f
                break
            end
        end
        if not frame then
            frame = CreateHistoryFrame()
            table.insert(historyFramePool, frame)
        end
        activeHistoryFrames[playerName] = frame
        frame:SetScript("OnHide", function() activeHistoryFrames[playerName] = nil end)
        
        local numActive = 0
        for _ in pairs(activeHistoryFrames) do numActive = numActive + 1 end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", (numActive-1) * 20, (numActive-1) * -20)
        frame:SetFrameLevel(math.max(10, 100 - numActive))
    end
    
    frame.playerName = playerName
    frame.context = context
    
    if context == "member" then
        frame.respBtn:Hide()
        frame.blockBtn:Hide()
        frame.inviteBtn:SetText("Party Invite")
        frame.inviteBtn:SetWidth(85)
        frame.inviteBtn:ClearAllPoints()
        frame.inviteBtn:SetPoint("LEFT", frame.sendBtn, "RIGHT", 5, 0)
    else
        frame.respBtn:Show()
        frame.blockBtn:Show()
        frame.inviteBtn:SetText("Invite")
        frame.inviteBtn:SetWidth(60)
        frame.inviteBtn:ClearAllPoints()
        frame.inviteBtn:SetPoint("LEFT", frame.respBtn, "RIGHT", 5, 0)
    end

    local history = addonTable.db.Leads[playerName] and addonTable.db.Leads[playerName].whisperHistory
    if not history and addonTable.GetMembersDB() and addonTable.GetMembersDB()[playerName] then
        history = addonTable.GetMembersDB()[playerName].whisperHistory
    end
    
    if not history or #history == 0 then
        frame.historyText:SetText("No whisper history found for " .. playerName .. ".")
    else
        local text = ""
        for _, entry in ipairs(history) do
            local timeStr = date("%m/%d %H:%M:%S", entry.timestamp or time())
            local msgText = entry.text or entry.message or ""
            if entry.direction == "out" or entry.type == "OUT" then
                text = text .. "|cFFFFFF00[" .. timeStr .. "] To " .. playerName .. ":|r " .. msgText .. "\n\n"
            else
                text = text .. "|cFF00FFFF[" .. timeStr .. "] From " .. playerName .. ":|r " .. msgText .. "\n\n"
            end
        end
        frame.historyText:SetText(text)
    end
    
    frame.textFrame:SetHeight(math.max(frame.historyText:GetStringHeight(), 1))
    
    C_Timer.After(0.05, function()
        frame.scroll:SetVerticalScroll(frame.scroll:GetVerticalScrollRange())
    end)
    
    local statusStr = ""
    if addonTable.db and addonTable.db.Leads and addonTable.db.Leads[playerName] and addonTable.db.Leads[playerName].status then
        local st = addonTable.db.Leads[playerName].status
        if st == "Accepted" then
            statusStr = " |cFF00FF00[Accepted]|r"
        elseif st == "Denied" then
            statusStr = " |cFFFF0000[Denied]|r"
        else
            statusStr = " [" .. st .. "]"
        end
    end
    frame.TitleText:SetText("Messages: " .. playerName .. statusStr)
    frame:Show()
end

local function CreateCandidateRow(index)
    local row = CreateFrame("Frame", nil, CandScrollChild)
    row:SetSize(800, CAND_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * CAND_ROW_HEIGHT))

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)

    row.btnLinkAlt = CreateFrame("Button", nil, row)
    row.btnLinkAlt:SetSize(16, 16); row.btnLinkAlt:SetPoint("LEFT", 5, 0)
    row.btnLinkAlt:SetNormalTexture("Interface\\Icons\\Ability_Rogue_Disguise")
    row.btnLinkAlt:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnLinkAlt:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Link to an Alt"); GameTooltip:Show() end)
    row.btnLinkAlt:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnLinkAlt:SetScript("OnClick", function()
        if row.playerName then
            StaticPopup_Show("GR_LINK_ALT", row.playerName)
            addonTable._linkAltTarget = row.playerName
        end
    end)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 25, 0); row.nameText:SetWidth(85); row.nameText:SetJustifyH("LEFT")

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.levelText:SetPoint("LEFT", 110, 0); row.levelText:SetWidth(30); row.levelText:SetJustifyH("LEFT")

    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.classText:SetPoint("LEFT", 145, 0); row.classText:SetWidth(65); row.classText:SetJustifyH("LEFT")

    row.notesBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.notesBox:SetSize(140, 18); row.notesBox:SetPoint("LEFT", 215, 0)
    row.notesBox:SetAutoFocus(false)
    row.notesBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if row.playerName and addonTable.db.Leads[row.playerName] then
            addonTable.db.Leads[row.playerName].notes = self:GetText()
        end
    end)

    row.btnTemplate = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.btnTemplate:SetSize(80, 20); row.btnTemplate:SetPoint("LEFT", 370, 0)
    row.btnTemplate:SetText("Whisper >>")
    row.btnTemplate:SetScript("OnClick", function(self)
        if row.playerName then addonTable.ShowTemplateMenu(self, row.playerName) end
    end)

    row.btnInvite = CreateFrame("Button", nil, row)
    row.btnInvite:SetSize(22, 22); row.btnInvite:SetPoint("LEFT", row.btnTemplate, "RIGHT", 5, 0)
    row.btnInvite:SetNormalTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing02")
    row.btnInvite:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnInvite:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Invite to Guild"); GameTooltip:Show() end)
    row.btnInvite:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnInvite:SetScript("OnClick", function()
        if row.playerName and addonTable.InviteLead then addonTable.InviteLead(row.playerName) end
    end)

    row.btnBlacklist = CreateFrame("Button", nil, row)
    row.btnBlacklist:SetSize(22, 22); row.btnBlacklist:SetPoint("LEFT", row.btnInvite, "RIGHT", 5, 0)
    row.btnBlacklist:SetNormalTexture("Interface\\Icons\\INV_Misc_Bone_Skull_02")
    row.btnBlacklist:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnBlacklist:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Block (Blacklist)"); GameTooltip:Show() end)
    row.btnBlacklist:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnBlacklist:SetScript("OnClick", function()
        if row.playerName then
            addonTable.db.Leads[row.playerName].status = "Blacklisted"
            addonTable.db.Blacklist[row.playerName] = true
            CRM.UpdateCandidateList()
        end
    end)

    row.btnRemove = CreateFrame("Button", nil, row)
    row.btnRemove:SetSize(22, 22); row.btnRemove:SetPoint("LEFT", row.btnBlacklist, "RIGHT", 5, 0)
    row.btnRemove:SetNormalTexture("Interface\\Icons\\Spell_ChargeNegative")
    row.btnRemove:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnRemove:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Remove from candidates"); GameTooltip:Show() end)
    row.btnRemove:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnRemove:SetScript("OnClick", function()
        if row.playerName then
            addonTable.db.Leads[row.playerName].hidden = true
            CRM.UpdateCandidateList()
            if CRM.UpdateSearchResults then CRM.UpdateSearchResults() end
        end
    end)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", row.btnRemove, "RIGHT", 15, 0); row.statusText:SetWidth(150); row.statusText:SetJustifyH("LEFT")

    row.btnHistory = CreateFrame("Button", nil, row)
    row.btnHistory:SetSize(22, 22); row.btnHistory:SetPoint("LEFT", row.statusText, "RIGHT", 10, 0)
    row.btnHistory:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
    row.btnHistory:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnHistory:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Messages")
        GameTooltip:Show()
    end)
    row.btnHistory:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnHistory:SetScript("OnClick", function()
        if row.playerName then addonTable.ShowHistory(row.playerName) end
    end)

    return row
end

function CRM.UpdateCandidateList()
    for _, row in ipairs(candidateRows) do row:Hide() end

    local index = 1
    local totalHeight = 0

    local sortedCand = {}
    if addonTable.db and addonTable.db.Leads then
        for name, data in pairs(addonTable.db.Leads) do
            if data.status ~= "Blacklisted" and data.status ~= "New" and not data.hidden then
                table.insert(sortedCand, name)
            end
        end
        
        table.sort(sortedCand, function(a, b)
            local dataA = addonTable.db.Leads[a]
            local dataB = addonTable.db.Leads[b]
            local valA, valB
            
            if candSortCol == "level" then
                valA = tonumber(dataA.level) or 0
                valB = tonumber(dataB.level) or 0
            elseif candSortCol == "class" then
                valA = tostring(dataA.class or "")
                valB = tostring(dataB.class or "")
            elseif candSortCol == "status" then
                valA = dataA.status or ""
                valB = dataB.status or ""
            elseif candSortCol == "notes" then
                valA = dataA.notes or ""
                valB = dataB.notes or ""
            else
                valA = a
                valB = b
            end
            
            if candSortAsc then
                return valA < valB
            else
                return valA > valB
            end
        end)

        for _, name in ipairs(sortedCand) do
            local data = addonTable.db.Leads[name]
            local row = candidateRows[index]
            if not row then
                row = CreateCandidateRow(index)
                table.insert(candidateRows, row)
            end

            row.playerName = name
            row.nameText:SetText(name)
            local c = RAID_CLASS_COLORS[string.upper(tostring(data.class or ""))]
            if c then row.nameText:SetTextColor(c.r, c.g, c.b)
            else row.nameText:SetTextColor(1, 1, 1) end

            row.levelText:SetText(tostring(data.level or "?"))
            row.classText:SetText(data.class or "?")

            local status = data.status or "Pitched"
            local displayStatus = status
            if data.claimedBy and data.claimedBy ~= UnitName("player") then
                displayStatus = status .. "\n|cFF888888(" .. data.claimedBy .. ")|r"
            end
            row.statusText:SetText(displayStatus)
            if status == "Joined" then row.statusText:SetTextColor(0, 1, 0)
            elseif status == "Interviewing" then row.statusText:SetTextColor(1, 0.8, 0)
            elseif status == "Pitched" then row.statusText:SetTextColor(0.6, 0.8, 1)
            elseif status == "Waitlisted" then row.statusText:SetTextColor(0.7, 0.7, 0.7)
            else row.statusText:SetTextColor(1, 1, 1) end

            row.notesBox:SetText(data.notes or "")
            row:Show()
            index = index + 1
            totalHeight = totalHeight + CAND_ROW_HEIGHT
        end
    end
    CandScrollChild:SetHeight(math.max(totalHeight, 1))
end

-- Bottom bar for Candidates tab
local candBottom = CreateFrame("Frame", nil, CandidatesContent)
candBottom:SetSize(800, 30)
candBottom:SetPoint("BOTTOMLEFT", 0, 5)

local btnClearPitched = CreateFrame("Button", nil, candBottom, "UIPanelButtonTemplate")
btnClearPitched:SetSize(120, 25); btnClearPitched:SetPoint("LEFT", 10, 0)
btnClearPitched:SetText("Clear Pitched")
btnClearPitched:SetScript("OnClick", function()
    for name, data in pairs(addonTable.db.Leads) do
        if data.status == "Pitched" then
            data.hidden = true
        end
    end
    CRM.UpdateCandidateList()
    if CRM.UpdateSearchResults then CRM.UpdateSearchResults() end
end)

---------------------------------------------------------------------------
-- TEMPLATE DROPDOWN MENU (shared by both tabs)
---------------------------------------------------------------------------
local templateMenu = CreateFrame("Frame", "GRTemplateMenu", UIParent, "UIDropDownMenuTemplate")

function addonTable.ShowTemplateMenu(anchorFrame, playerName)
    -- Modern 11.0+ Menu API
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchorFrame, function(ownerRegion, rootDescription)
            local templates = addonTable.db.Config.Templates or {}
            local added = false
            for i = 1, 5 do
                local tmpl = templates[i]
                if tmpl and tmpl ~= "" then
                    added = true
                    rootDescription:CreateButton("T" .. i .. ": " .. strsub(tmpl, 1, 40), function()
                        addonTable.QueueBulkWhisper(playerName, tmpl)
                        if addonTable.db.Leads[playerName] then
                            addonTable.db.Leads[playerName].status = "Pitched"
                            if CRM.UpdateSearchResults then CRM.UpdateSearchResults() end
                            if CRM.UpdateCandidateList then CRM.UpdateCandidateList() end
                        end
                    end)
                end
            end
            if not added then
                rootDescription:CreateTitle("No templates configured")
            end
        end)
        return
    end

    -- Legacy fallback
    local menuList = {}
    local templates = addonTable.db.Config.Templates or {}

    for i = 1, 5 do
        local tmpl = templates[i]
        if tmpl and tmpl ~= "" then
            table.insert(menuList, {
                text = "T" .. i .. ": " .. strsub(tmpl, 1, 40),
                func = function()
                    addonTable.QueueBulkWhisper(playerName, tmpl)
                    if addonTable.db.Leads[playerName] then
                        addonTable.db.Leads[playerName].status = "Pitched"
                        if CRM.UpdateSearchResults then CRM.UpdateSearchResults() end
                        if CRM.UpdateCandidateList then CRM.UpdateCandidateList() end
                    end
                end,
                notCheckable = true,
            })
        end
    end

    if #menuList == 0 then
        table.insert(menuList, {
            text = "No templates configured",
            disabled = true,
            notCheckable = true,
        })
    end

    if EasyMenu then
        EasyMenu(menuList, templateMenu, anchorFrame, 0, 0, "MENU")
    else
        print("|cFFFF0000[Guild Recruiter]|r Error: Dropdown menu system not found.")
    end
end

---------------------------------------------------------------------------
-- RESPONSE DROPDOWN MENU
---------------------------------------------------------------------------
function addonTable.ShowResponseMenu(anchorFrame, playerName)
    -- Modern 11.0+ Menu API
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchorFrame, function(ownerRegion, rootDescription)
            local responses = addonTable.db.Config.Responses or {}
            local added = false
            for i = 1, 3 do
                local resp = responses[i]
                if resp and resp ~= "" then
                    added = true
                    rootDescription:CreateButton("R" .. i .. ": " .. strsub(resp, 1, 40), function()
                        SendChatMessage(resp, "WHISPER", nil, playerName)
                    end)
                end
            end
            local infoMsg = addonTable.db.Config.WelcomeInfoMessage
            if infoMsg and infoMsg ~= "" then
                added = true
                rootDescription:CreateButton("Send Guild Info", function()
                    local msg = string.gsub(infoMsg, "%%[tT]", playerName)
                    SendChatMessage(msg, "WHISPER", nil, playerName)
                end)
            end

            if not added then
                rootDescription:CreateTitle("No responses configured")
            end
        end)
        return
    end

    -- Legacy fallback
    local menuList = {}
    local responses = addonTable.db.Config.Responses or {}

    for i = 1, 3 do
        local resp = responses[i]
        if resp and resp ~= "" then
            table.insert(menuList, {
                text = "R" .. i .. ": " .. strsub(resp, 1, 40),
                func = function()
                    SendChatMessage(resp, "WHISPER", nil, playerName)
                end,
                notCheckable = true,
            })
        end
    end

    local infoMsg = addonTable.db.Config.WelcomeInfoMessage
    if infoMsg and infoMsg ~= "" then
        table.insert(menuList, {
            text = "Send Guild Info",
            func = function()
                local msg = string.gsub(infoMsg, "%%[tT]", playerName)
                SendChatMessage(msg, "WHISPER", nil, playerName)
            end,
            notCheckable = true,
        })
    end

    if #menuList == 0 then
        table.insert(menuList, {
            text = "No responses configured",
            disabled = true,
            notCheckable = true,
        })
    end

    if EasyMenu then
        EasyMenu(menuList, GRTemplateMenu, anchorFrame, 0, 0, "MENU")
    else
        print("|cFFFF0000[Guild Recruiter]|r Error: Dropdown menu system not found.")
    end
end

---------------------------------------------------------------------------
-- LINK ALT STATIC POPUP
---------------------------------------------------------------------------
StaticPopupDialogs["GR_LINK_ALT"] = {
    text = "Enter the alt/main name to link to %s:",
    button1 = "Link",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        local altName = self.editBox:GetText()
        local targetName = addonTable._linkAltTarget
        if altName and altName ~= "" and targetName and addonTable.db.Leads[targetName] then
            if not addonTable.db.Leads[targetName].alts then
                addonTable.db.Leads[targetName].alts = {}
            end
            table.insert(addonTable.db.Leads[targetName].alts, altName)

            if addonTable.db.Leads[altName] then
                local altHistory = addonTable.db.Leads[altName].whisperHistory or {}
                if not addonTable.db.Leads[targetName].whisperHistory then
                    addonTable.db.Leads[targetName].whisperHistory = {}
                end
                for _, entry in ipairs(altHistory) do
                    table.insert(addonTable.db.Leads[targetName].whisperHistory, entry)
                end
                addonTable.db.Leads[altName] = nil
            end

            print("|cFF00FF00[Guild Recruiter]|r Linked " .. altName .. " as alt of " .. targetName)
        end
        addonTable._linkAltTarget = nil
    end,
    OnCancel = function()
        addonTable._linkAltTarget = nil
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

---------------------------------------------------------------------------
-- MEMBERS TAB
---------------------------------------------------------------------------
local chkOnlineOnly = CreateFrame("CheckButton", nil, MembersContent, "ChatConfigCheckButtonTemplate")
chkOnlineOnly:SetPoint("TOPLEFT", 10, -5)
chkOnlineOnly.Text:SetText("Online Only")
chkOnlineOnly:SetHitRectInsets(0, -chkOnlineOnly.Text:GetStringWidth() - 5, 0, 0)
chkOnlineOnly:SetChecked(false)
chkOnlineOnly:SetScript("OnClick", function()
    CRM.UpdateMembersList()
end)

local lblMembersCount = MembersContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblMembersCount:SetPoint("LEFT", chkOnlineOnly.Text, "RIGHT", 20, 0)
lblMembersCount:SetText("Online: 0 / Total: 0")

local memHeaders = CreateFrame("Frame", nil, MembersContent)
memHeaders:SetSize(800, 20)
memHeaders:SetPoint("TOPLEFT", 5, -30)

local memSortCol = "name"
local memSortAsc = true

local memHeaderNames = {"Name", "Lvl", "Class", "Rank", "Status", "Last On", "Pub Note", "Off Note", "Actions"}
local memHeaderKeys = {"name", "level", "class", "rank", "status", "lastOnline", "publicNote", "officerNote", nil}
local memHeaderWidths = {130, 30, 60, 60, 60, 60, 110, 110, 130}
local memHeaderX = 10
for i, hName in ipairs(memHeaderNames) do
    if memHeaderKeys[i] then
        local btn = CreateFrame("Button", nil, memHeaders)
        btn:SetSize(memHeaderWidths[i], 16)
        btn:SetPoint("LEFT", memHeaderX, 0)
        local h = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", 0, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
        btn:SetScript("OnClick", function()
            if memSortCol == memHeaderKeys[i] then
                memSortAsc = not memSortAsc
            else
                memSortCol = memHeaderKeys[i]
                memSortAsc = true
            end
            CRM.UpdateMembersList()
        end)
    else
        local h = memHeaders:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("LEFT", memHeaderX, 0)
        h:SetText(hName)
        h:SetTextColor(1, 0.82, 0)
    end
    memHeaderX = memHeaderX + memHeaderWidths[i]
end

local MemScroll = CreateFrame("ScrollFrame", "GRMembersScrollFrame", MembersContent, "UIPanelScrollFrameTemplate")
MemScroll:SetPoint("TOPLEFT", 5, -50)
MemScroll:SetPoint("BOTTOMRIGHT", -30, 40)

local MemScrollChild = CreateFrame("Frame")
MemScrollChild:SetSize(1, 1)
MemScroll:SetScrollChild(MemScrollChild)

local memberRows = {}
local MEM_ROW_HEIGHT = 28

-- Bottom bar for Members tab
local memBottom = CreateFrame("Frame", nil, MembersContent)
memBottom:SetSize(800, 30)
memBottom:SetPoint("BOTTOMLEFT", 0, 5)

local btnPurgeInactive = CreateFrame("Button", nil, memBottom, "UIPanelButtonTemplate")
btnPurgeInactive:SetSize(130, 25); btnPurgeInactive:SetPoint("LEFT", 10, 0)
btnPurgeInactive:SetText("Clear Leavers")
btnPurgeInactive:SetScript("OnClick", function()
    local count = 0
    local membersDB = addonTable.GetMembersDB()
    if not membersDB then
        print("|cFF00FF00[Guild Recruiter]|r You must be in a guild to clear leavers.")
        return
    end

    for name, data in pairs(membersDB) do
        if data.isLeaver then
            membersDB[name] = nil
            if addonTable.db.Blacklist then
                addonTable.db.Blacklist[name] = true
            end
            count = count + 1
        end
    end
    print("|cFF00FF00[Guild Recruiter]|r Cleared and blacklisted " .. count .. " leavers.")
    if CRM.UpdateMembersList then CRM.UpdateMembersList() end
end)

StaticPopupDialogs["GR_SHARE_INFO_CONFIRM"] = {
    text = "This will broadcast your local Blacklist and Alt/Main links to all online officers using Guild Recruiter. Are you sure?",
    button1 = "Share",
    button2 = "Cancel",
    OnAccept = function()
        local countBlacklist = 0
        local countAlts = 0
        if addonTable.db and addonTable.db.Blacklist then
            for name, isBlacklisted in pairs(addonTable.db.Blacklist) do
                if isBlacklisted and addonTable.SyncStatus then
                    addonTable.SyncStatus(name, "Blacklisted")
                    countBlacklist = countBlacklist + 1
                end
            end
        end
        if addonTable.db and addonTable.GetMembersDB() then
            for name, data in pairs(addonTable.GetMembersDB()) do
                if data.mainLink and addonTable.SyncAlt then
                    addonTable.SyncAlt(name, data.mainLink)
                    countAlts = countAlts + 1
                end
            end
        end
        print(string.format("|cFF00FF00[Guild Recruiter]|r Shared %d blacklist entries and %d alt links with online officers.", countBlacklist, countAlts))
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local btnShareInfo = CreateFrame("Button", nil, memBottom, "UIPanelButtonTemplate")
btnShareInfo:SetSize(150, 25); btnShareInfo:SetPoint("LEFT", btnPurgeInactive, "RIGHT", 10, 0)
btnShareInfo:SetText("Share Info")
btnShareInfo:SetScript("OnClick", function()
    StaticPopup_Show("GR_SHARE_INFO_CONFIRM")
end)

local btnRefresh = CreateFrame("Button", nil, memBottom, "UIPanelButtonTemplate")
btnRefresh:SetSize(100, 25); btnRefresh:SetPoint("LEFT", btnShareInfo, "RIGHT", 10, 0)
btnRefresh:SetText("Refresh")
btnRefresh:SetScript("OnClick", function()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
    print("|cFF00FF00[Guild Recruiter]|r Requested roster update from server.")
end)

StaticPopupDialogs["GR_LINK_MEMBER_ALT"] = {
    text = "Enter the main name to link %s to:",
    button1 = "Link",
    button2 = "Cancel",
    hasEditBox = true,
    editBoxWidth = 200,
    OnShow = function(self)
        local editBox = self.editBox or self.EditBox
        if editBox then
            editBox:SetText("")
            editBox:SetScript("OnTextChanged", function(box, userInput)
                if not userInput then return end
                local text = box:GetText()
                if string.len(text) > 0 and addonTable.db and addonTable.GetMembersDB() then
                    for name, _ in pairs(addonTable.GetMembersDB()) do
                        if string.lower(string.sub(name, 1, string.len(text))) == string.lower(text) then
                            box:SetText(name)
                            box:HighlightText(string.len(text), string.len(name))
                            box:SetCursorPosition(string.len(text))
                            break
                        end
                    end
                end
            end)
        end
    end,
    OnHide = function(self)
        local editBox = self.editBox or self.EditBox
        if editBox then
            editBox:SetScript("OnTextChanged", nil)
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or self.EditBox
        local mainName = editBox and editBox:GetText() or ""
        local targetName = addonTable._linkAltTarget
        if mainName ~= "" and targetName and addonTable.GetMembersDB()[targetName] then
            addonTable.GetMembersDB()[targetName].mainLink = mainName
            if CRM.UpdateMembersList then CRM.UpdateMembersList() end
        end
        addonTable._linkAltTarget = nil
    end,
    OnCancel = function() addonTable._linkAltTarget = nil end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local GkickConfirmFrame = CreateFrame("Frame", "GR_GkickConfirmFrame", UIParent, "BasicFrameTemplateWithInset")
GkickConfirmFrame:SetSize(300, 150)
GkickConfirmFrame:SetPoint("CENTER")
GkickConfirmFrame:Hide()
GkickConfirmFrame:SetFrameStrata("DIALOG")
GkickConfirmFrame.TitleText:SetText("Confirm Guild Kick")

local GkickText = GkickConfirmFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
GkickText:SetPoint("CENTER", GkickConfirmFrame, "CENTER", 0, 10)
GkickText:SetText("Are you sure you want to kick?")

local GkickConfirmBtn = CreateFrame("Button", nil, GkickConfirmFrame, "SecureActionButtonTemplate, UIPanelButtonTemplate")
GkickConfirmBtn:SetSize(90, 25)
GkickConfirmBtn:SetPoint("BOTTOMLEFT", 40, 20)
GkickConfirmBtn:SetText("Kick")
GkickConfirmBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
GkickConfirmBtn:SetAttribute("type", "macro")
GkickConfirmBtn:SetScript("PostClick", function()
    GkickConfirmFrame:Hide()
    if addonTable._gkickTarget then
        -- Post-macro actions
        addonTable.db.Blacklist[addonTable._gkickTarget] = true
        if not addonTable.db.Leads[addonTable._gkickTarget] then
            addonTable.db.Leads[addonTable._gkickTarget] = { timeSeen = time() }
        end
        addonTable.db.Leads[addonTable._gkickTarget].status = "Blacklisted"
        if addonTable.SyncStatus then
            addonTable.SyncStatus(addonTable._gkickTarget, "Blacklisted")
        end
        addonTable._gkickTarget = nil
        if CRM.UpdateMembersList then CRM.UpdateMembersList() end
    end
end)

local GkickCancelBtn = CreateFrame("Button", nil, GkickConfirmFrame, "UIPanelButtonTemplate")
GkickCancelBtn:SetSize(90, 25)
GkickCancelBtn:SetPoint("BOTTOMRIGHT", -40, 20)
GkickCancelBtn:SetText("Cancel")
GkickCancelBtn:SetScript("OnClick", function()
    GkickConfirmFrame:Hide()
    addonTable._gkickTarget = nil
end)

local function CreateMemberRow(index)
    local row = CreateFrame("Frame", nil, MemScrollChild)
    row:SetSize(800, MEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * MEM_ROW_HEIGHT))

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)

    row.mainAltIcon = CreateFrame("Button", nil, row)
    row.mainAltIcon:SetSize(16, 16)
    row.mainAltIcon:SetPoint("LEFT", 5, 0)
    row.mainAltIcon:SetScript("OnClick", function()
        if row.playerName then
            addonTable._linkAltTarget = row.playerName
            StaticPopup_Show("GR_LINK_MEMBER_ALT", row.playerName)
        end
    end)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 25, 0); row.nameText:SetWidth(105); row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.levelText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.levelText:SetPoint("LEFT", 135, 0); row.levelText:SetWidth(30); row.levelText:SetJustifyH("LEFT")
    
    row.classText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.classText:SetPoint("LEFT", 165, 0); row.classText:SetWidth(60); row.classText:SetJustifyH("LEFT")

    row.rankText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.rankText:SetPoint("LEFT", 225, 0); row.rankText:SetWidth(60); row.rankText:SetJustifyH("LEFT")
    row.rankText:SetWordWrap(false)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", 285, 0); row.statusText:SetWidth(60); row.statusText:SetJustifyH("LEFT")

    row.lastOnlineText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.lastOnlineText:SetPoint("LEFT", 345, 0); row.lastOnlineText:SetWidth(60); row.lastOnlineText:SetJustifyH("LEFT")

    row.pubNoteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.pubNoteText:SetPoint("LEFT", 405, 0); row.pubNoteText:SetWidth(110); row.pubNoteText:SetJustifyH("LEFT")
    row.pubNoteText:SetWordWrap(false)

    row.offNoteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.offNoteText:SetPoint("LEFT", 515, 0); row.offNoteText:SetWidth(110); row.offNoteText:SetJustifyH("LEFT")
    row.offNoteText:SetWordWrap(false)

    -- Actions
    row.btnWhisper = CreateFrame("Button", nil, row)
    row.btnWhisper:SetSize(22, 22); row.btnWhisper:SetPoint("LEFT", 630, 0)
    row.btnWhisper:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
    row.btnWhisper:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnWhisper:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Messages"); GameTooltip:Show() end)
    row.btnWhisper:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnWhisper:SetScript("OnClick", function()
        if row.playerName then
            addonTable.ShowHistory(row.playerName, "member")
        end
    end)

    row.btnInviteParty = CreateFrame("Button", nil, row)
    row.btnInviteParty:SetSize(22, 22); row.btnInviteParty:SetPoint("LEFT", row.btnWhisper, "RIGHT", 5, 0)
    row.btnInviteParty:SetNormalTexture("Interface\\Icons\\Spell_Holy_PrayerOfHealing02")
    row.btnInviteParty:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    row.btnInviteParty:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Invite to Party/Raid"); GameTooltip:Show() end)
    row.btnInviteParty:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.btnInviteParty:SetScript("OnClick", function()
        if row.playerName then
            if C_PartyInfo and C_PartyInfo.InviteUnit then
                C_PartyInfo.InviteUnit(row.playerName)
            else
                InviteUnit(row.playerName)
            end
        end
    end)

    row.btnRemoveLeaver = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.btnRemoveLeaver:SetSize(50, 20); row.btnRemoveLeaver:SetPoint("RIGHT", row, "RIGHT", -25, 0)
    row.btnRemoveLeaver:SetText("Clear")
    row.btnRemoveLeaver:SetScript("OnClick", function()
        if row.playerName then
            addonTable.GetMembersDB()[row.playerName] = nil
            CRM.UpdateMembersList()
        end
    end)

    return row
end

function CRM.UpdateMembersList()
    if not addonTable.db or not addonTable.GetMembersDB() then return end
    
    for _, row in ipairs(memberRows) do row:Hide() end

    local index = 1
    local totalHeight = 0
    local sortedNames = {}
    
    local onlineCount = 0
    local totalCount = 0
    local onlineOnly = chkOnlineOnly:GetChecked()
    
    for name, data in pairs(addonTable.GetMembersDB()) do
        totalCount = totalCount + 1
        if data.isOnline then onlineCount = onlineCount + 1 end
        
        if not onlineOnly or data.isOnline then
            table.insert(sortedNames, name)
        end
    end
    
    lblMembersCount:SetText("Online: " .. onlineCount .. " / Total: " .. totalCount)
    
    local mainToAlts = {}
    for name, data in pairs(addonTable.GetMembersDB()) do
        if data.mainLink then
            if not mainToAlts[data.mainLink] then mainToAlts[data.mainLink] = {} end
            table.insert(mainToAlts[data.mainLink], name)
        end
    end
    
    table.sort(sortedNames, function(a, b)
        local dataA = addonTable.GetMembersDB()[a]
        local dataB = addonTable.GetMembersDB()[b]
        
        local groupA = dataA.mainLink or a
        local groupB = dataB.mainLink or b
        
        if groupA == groupB then
            if a == groupA then return true end
            if b == groupB then return false end
            return a < b
        end
        
        local groupDataA = addonTable.GetMembersDB()[groupA] or dataA
        local groupDataB = addonTable.GetMembersDB()[groupB] or dataB
        
        local valA, valB
        if memSortCol == "level" then
            valA = tonumber(groupDataA.level) or 0
            valB = tonumber(groupDataB.level) or 0
        elseif memSortCol == "class" then
            valA = tostring(groupDataA.class or "")
            valB = tostring(groupDataB.class or "")
        elseif memSortCol == "publicNote" then
            valA = groupDataA.publicNote or ""
            valB = groupDataB.publicNote or ""
        elseif memSortCol == "officerNote" then
            valA = groupDataA.officerNote or ""
            valB = groupDataB.officerNote or ""
        elseif memSortCol == "rank" then
            valA = groupDataA.rankIndex or 99
            valB = groupDataB.rankIndex or 99
        elseif memSortCol == "lastOnline" then
            valA = groupDataA.lastOnlineTime or 0
            valB = groupDataB.lastOnlineTime or 0
        elseif memSortCol == "status" then
            valA = groupDataA.isLeaver and "Leaver" or (groupDataA.isNew and "New" or "Existing")
            valB = groupDataB.isLeaver and "Leaver" or (groupDataB.isNew and "New" or "Existing")
        else
            valA = groupA
            valB = groupB
        end
        
        if valA ~= valB then
            if memSortAsc then return valA < valB else return valA > valB end
        else
            return groupA < groupB
        end
    end)
    
    local currentTime = time()
    -- Get guild roster info to map name -> index for note editing
    local nameToIndex = {}
    if IsInGuild() then
        for i=1, GetNumGuildMembers() do
            local n = GetGuildRosterInfo(i)
            if n then
                n = strsplit("-", n)
                nameToIndex[n] = i
            end
        end
    end

    local isLeader = IsGuildLeader and IsGuildLeader()

    for _, name in ipairs(sortedNames) do
        local data = addonTable.GetMembersDB()[name]
        local row = memberRows[index]
        if not row then
            row = CreateMemberRow(index)
            table.insert(memberRows, row)
        end

        row.playerName = name
        row.playerIndex = data.rosterIndex or nameToIndex[name]
        row.playerGuid = data.guid
        
        row.nameText:SetText(name)
        
        if data.mainLink then
            row.mainAltIcon:SetNormalTexture("Interface\\Icons\\Spell_ChargeNegative")
            row.mainAltIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Alt of " .. data.mainLink .. "\n|cFF888888Click to link/edit main|r")
                GameTooltip:Show()
            end)
            row.mainAltIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.mainAltIcon:Show()
            row.nameText:SetPoint("LEFT", 35, 0)
            row.nameText:SetWidth(95)
        elseif mainToAlts[name] then
            row.mainAltIcon:SetNormalTexture("Interface\\Icons\\Spell_ChargePositive")
            row.mainAltIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Main Character\n|cFF888888Click to link/edit main|r")
                for _, altName in ipairs(mainToAlts[name]) do
                    GameTooltip:AddLine("- " .. altName, 0.8, 0.8, 0.8)
                end
                GameTooltip:Show()
            end)
            row.mainAltIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.mainAltIcon:Show()
            row.nameText:SetPoint("LEFT", 25, 0)
            row.nameText:SetWidth(105)
        else
            row.mainAltIcon:SetNormalTexture("Interface\\Icons\\Ability_Rogue_Disguise")
            row.mainAltIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Unlinked\n|cFF888888Click to link to a Main|r")
                GameTooltip:Show()
            end)
            row.mainAltIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row.mainAltIcon:Show()
            row.nameText:SetPoint("LEFT", 25, 0)
            row.nameText:SetWidth(105)
        end
        
        local c = RAID_CLASS_COLORS[string.upper(tostring(data.class or ""))]
        if c then row.nameText:SetTextColor(c.r, c.g, c.b)
        else row.nameText:SetTextColor(1, 1, 1) end

        local lvlText = tostring(data.level or "?")
        if data.oldLevel and tonumber(data.level) and tonumber(data.oldLevel) then
            local diff = tonumber(data.level) - tonumber(data.oldLevel)
            if diff > 0 then
                lvlText = lvlText .. " |cFF00FF00(+" .. diff .. ")|r"
            end
        end
        row.levelText:SetText(lvlText)
        row.classText:SetText(data.classDisplayName or data.class or "?")

        row.pubNoteText:SetText(data.publicNote or "")
        row.offNoteText:SetText(data.officerNote or "")
        
        row.rankText:SetText(data.rankName or "")

        local statusText = ""
        local isOnlineNow = data.isOnline
        if data.isLeaver then
            statusText = "|cFFFF0000Leaver|r"
        elseif data.isNew then
            statusText = "|cFF00FF00New|r"
        else
            -- Check inactive > 30 days
            if (currentTime - (data.lastOnlineTime or currentTime)) > 30 * 86400 then
                statusText = "|cFFFFA500Inactive|r"
            else
                statusText = "Existing"
            end
        end
        row.statusText:SetText(statusText)
        
        local lastOnlineStr = ""
        if isOnlineNow then
            lastOnlineStr = "|cFF00FF00Online|r"
        elseif data.lastOnlineTime then
            local diff = currentTime - data.lastOnlineTime
            if diff < 3600 then
                lastOnlineStr = math.floor(diff/60) .. " mins"
            elseif diff < 86400 then
                lastOnlineStr = math.floor(diff/3600) .. " hrs"
            else
                lastOnlineStr = math.floor(diff/86400) .. " days"
            end
        else
            lastOnlineStr = "Unknown"
        end
        row.lastOnlineText:SetText(lastOnlineStr)

        if data.isLeaver then
            row.btnRemoveLeaver:Show()
        else
            row.btnRemoveLeaver:Hide()
        end

        row:Show()
        index = index + 1
        totalHeight = totalHeight + MEM_ROW_HEIGHT
    end
    
    MemScrollChild:SetHeight(math.max(totalHeight, 1))
end

---------------------------------------------------------------------------
-- AUTO-REFRESH & EVENTS
---------------------------------------------------------------------------
MainFrame:HookScript("OnShow", function()
    SetActiveTab(activeTab)
end)

local crmEvents = CreateFrame("Frame")
crmEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
crmEvents:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" and MembersContent:IsShown() then
        if CRM.UpdateMembersList then CRM.UpdateMembersList() end
    end
end)

SetActiveTab(TAB_SEARCH)

