local addonName, addonTable = ...
local Scanner = CreateFrame("Frame")
addonTable.Scanner = Scanner

-- Configuration for our Scanners
local SCAN_INTERVAL = 10 -- seconds between /who queries to avoid DC
local searchQueue = {}
local isScanning = false
local timeSinceLastScan = 0

-- Register necessary modern APIs and events
Scanner:RegisterEvent("WHO_LIST_UPDATE")
Scanner:RegisterEvent("CHAT_MSG_CHANNEL")
Scanner:RegisterEvent("NAME_PLATE_UNIT_ADDED")
local lastWhoTime = 0

function addonTable.GetWhoCooldownRemaining()
    local now = time()
    if now - lastWhoTime < SCAN_INTERVAL then
        return SCAN_INTERVAL - (now - lastWhoTime)
    end
    return 0
end

-- Function to execute a search immediately (must be called from a hardware event to avoid blocks)
function addonTable.ExecuteWhoSearch(query)
    local remaining = addonTable.GetWhoCooldownRemaining()
    if remaining > 0 then
        if addonTable.SetSearchStatus then
            addonTable.SetSearchStatus("|cFFFF0000Please wait " .. remaining .. "s before searching again.|r")
        end
        return false
    end
    lastWhoTime = time()
    addonTable.RecentSearchResults = addonTable.RecentSearchResults or {}
    wipe(addonTable.RecentSearchResults)

    if addonTable.SetSearchStatus then
        addonTable.SetSearchStatus("Searching: /who " .. query)
    end
    
    local method = "NONE"
    if C_FriendList and C_FriendList.SendWho then
        C_FriendList.SendWho(query)
        method = "C_FriendList.SendWho"
    end
    addonTable.DebugLog("[DISPATCH] Used: " .. method .. " | Query: " .. query)
    
    addonTable.hideNextWhoWindow = true
    if C_FriendList and C_FriendList.SetWhoToUI then
        C_FriendList.SetWhoToUI(0)
    end
    
    if FriendsFrame then
        FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
    end

    C_Timer.After(0.05, function()
        local frames = {"WhoFrame", "FriendsFrame", "PVEFrame", "LookingForGroupFrame", "GroupFinderFrame", "LFGParentFrame", "LFGListFrame", "LFDParentFrame", "LFGFrame", "LFGWhoListFrame"}
        for _, name in ipairs(frames) do
            local f = _G[name]
            if f and f:IsShown() then 
                HideUIPanel(f) 
                f:Hide() 
            end
        end
    end)
end

-- Function to queue a new manual or automated search
function addonTable.QueueWhoSearch(query)
    table.insert(searchQueue, query)
end
local CITIES = {
    Alliance = {"Stormwind City", "Ironforge", "Darnassus"},
    Horde = {"Orgrimmar", "Undercity", "Thunder Bluff"}
}

function addonTable.StartProactiveScan()
    if addonTable.ClearNewLeads then addonTable.ClearNewLeads() end
    local myFaction = UnitFactionGroup("player")
    local myCities = CITIES[myFaction] or CITIES.Alliance
    
    -- Read from checkbox UI helpers
    local targetClasses = addonTable.GetCheckedClasses and addonTable.GetCheckedClasses() or {}
    local targetRaces = addonTable.GetCheckedRaces and addonTable.GetCheckedRaces() or {}
    local minLvl = addonTable.db.Config.FilterMinLevel or ""
    local maxLvl = addonTable.db.Config.FilterMaxLevel or ""
    local levels = ""
    if minLvl ~= "" and maxLvl ~= "" then levels = minLvl .. "-" .. maxLvl
    elseif minLvl ~= "" then levels = minLvl
    elseif maxLvl ~= "" then levels = maxLvl end
    -- If no classes checked, scan all (empty class filter = all classes)
    if #targetClasses == 0 then targetClasses = {""} end
    
    for _, city in ipairs(myCities) do
        for _, class in ipairs(targetClasses) do
            local query = 'z-"' .. city .. '"'
            if class ~= "" then query = query .. ' c-"' .. class .. '"' end
            if levels ~= "" then query = query .. ' ' .. levels end
            
            -- We filter races locally now in WHO_LIST_UPDATE, so we don't need to add r-"Race" to the server query,
            -- which was likely breaking the WoW API.
            addonTable.QueueWhoSearch(query, false)
        end
    end
    
    local filterDesc = (#targetClasses == 1 and targetClasses[1] == "") and "All Classes" or table.concat(targetClasses, ", ")
    if addonTable.SetSearchStatus then
        addonTable.SetSearchStatus("Scan built. Filters: " .. filterDesc)
    end
end

function addonTable.AdvanceProactiveScan(peekOnly)
    if #searchQueue > 0 then
        local remaining = addonTable.GetWhoCooldownRemaining()
        
        if peekOnly then return #searchQueue, remaining end
        
        if remaining > 0 then
            if addonTable.SetSearchStatus then
                addonTable.SetSearchStatus("|cFFFF0000Please wait " .. remaining .. "s before searching again.|r")
            end
            return #searchQueue, remaining
        end
        
        local nextQuery = table.remove(searchQueue, 1)
        addonTable.ExecuteWhoSearch(nextQuery)
        
        if addonTable.SetSearchStatus then
            if #searchQueue > 0 then
                addonTable.SetSearchStatus('Executed: "' .. nextQuery .. '". ' .. #searchQueue .. ' remaining in queue.')
            else
                addonTable.SetSearchStatus("Search complete. Queue empty.")
            end
        end
        
        return #searchQueue, 0
    else
        if not peekOnly and addonTable.SetSearchStatus then
            addonTable.SetSearchStatus("Search complete. Queue empty.")
        end
        return 0, 0
    end
end

function addonTable.StopProactiveScan()
    searchQueue = {}
    isScanning = false
    if addonTable.SetSearchStatus then
        addonTable.SetSearchStatus("Scan stopped. Queue cleared.")
    end
end

-- Event Handler
Scanner:SetScript("OnEvent", function(self, event, ...)
    if event == "WHO_LIST_UPDATE" then
        addonTable.DebugLog("[WHO_LIST_UPDATE] Event received.")
        
        if addonTable.hideNextWhoWindow then
            addonTable.hideNextWhoWindow = false
            if C_FriendList and C_FriendList.SetWhoToUI then
                C_FriendList.SetWhoToUI(1)
            elseif SetWhoToUI then
                SetWhoToUI(1)
            end
            
            if FriendsFrame then
                FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
            end
            
            -- Fallback hides just in case
            C_Timer.After(0.05, function()
                local frames = {"WhoFrame", "FriendsFrame", "PVEFrame", "LookingForGroupFrame", "GroupFinderFrame", "LFGParentFrame", "LFGListFrame", "LFDParentFrame", "LFGFrame", "LFGWhoListFrame"}
                for _, name in ipairs(frames) do
                    local f = _G[name]
                    if f and f:IsShown() then 
                        HideUIPanel(f) 
                        f:Hide() 
                    end
                end
            end)
        end
        
        -- Try modern API first, fall back to legacy globals
        local numResults = 0
        local useModernAPI = false
        
        if C_FriendList and C_FriendList.GetNumWhoResults then
            numResults = C_FriendList.GetNumWhoResults()
            addonTable.DebugLog("[API] Using C_FriendList.GetNumWhoResults: " .. numResults)
        else
             addonTable.DebugLog("[API] ERROR: C_FriendList.GetNumWhoResults not found.")
        end
        
        local newLeads = 0
        
        for i = 1, numResults do
            local name, guild, level, class, race
            
            if C_FriendList and C_FriendList.GetWhoInfo then
                local info = C_FriendList.GetWhoInfo(i)
                if info then
                    name = info.fullName
                    guild = info.fullGuildName
                    level = info.level
                    class = info.filename or info.classStr
                    race = info.raceStr
                end
            end
            
            if name and name ~= "" then
                -- Strip realm suffix if present (e.g. "Player-Realm" -> "Player")
                name = strsplit("-", name)
                
                -- Check the Unguilded filter
                local filterGuilded = addonTable.db.Config.FilterGuilded
                if filterGuilded == nil then filterGuilded = true end
                
                local passesFilter = true
                if filterGuilded and guild and guild ~= "" then
                    passesFilter = false
                end
                
                -- Check Class filter locally
                local targetClasses = addonTable.GetCheckedClasses and addonTable.GetCheckedClasses() or {}
                if passesFilter and #targetClasses > 0 and class then
                    local matchedClass = false
                    local classUpper = string.upper(tostring(class))
                    for _, tClass in ipairs(targetClasses) do
                        if string.upper(tClass) == classUpper then
                            matchedClass = true
                            break
                        end
                    end
                    if not matchedClass then passesFilter = false end
                end

                -- Check Race filter locally
                local targetRaces = addonTable.GetCheckedRaces and addonTable.GetCheckedRaces() or {}
                if passesFilter and #targetRaces > 0 and race then
                    local matchedRace = false
                    local raceUpper = string.upper(tostring(race))
                    for _, tRace in ipairs(targetRaces) do
                        if string.upper(tRace) == raceUpper then
                            matchedRace = true
                            break
                        end
                    end
                    if not matchedRace then passesFilter = false end
                end
                
                if passesFilter then
                    if not addonTable.RecentSearchResults then addonTable.RecentSearchResults = {} end
                    addonTable.RecentSearchResults[name] = true
                    
                    if not addonTable.db.Leads[name] then
                        addonTable.db.Leads[name] = {
                            level = level,
                            class = class,
                            status = "New",
                            timeSeen = time(),
                            source = "WhoScan"
                        }
                        newLeads = newLeads + 1
                    else
                        addonTable.db.Leads[name].timeSeen = time()
                        if level then addonTable.db.Leads[name].level = level end
                        if class then addonTable.db.Leads[name].class = class end
                    end
                end
            end
        end

        if addonTable.SetSearchStatus then
            addonTable.SetSearchStatus("/who returned " .. numResults .. " results, " .. newLeads .. " new leads added.")
        end

        -- Auto-refresh the CRM search list
        if addonTable.CRM and addonTable.CRM.UpdateSearchResults then
            addonTable.CRM.UpdateSearchResults()
        end

    elseif event == "CHAT_MSG_CHANNEL" then
        local msg, sender, _, _, _, _, _, channelIndex, channelName = ...
        if not addonTable.db.Config.EnableChatParser then return end
        
        local success, safeMsg = pcall(tostring, msg)
        if not success then return end
        local lmsg = string.lower(safeMsg)
        if string.find(lmsg, "lfg") or string.find(lmsg, "lfm") then
            -- Note: We can't immediately know if they are unguilded from chat,
            -- but we can flag them as a hot lead for manual review or queue a /who on them!
            local cleanName = strsplit("-", sender)
            if not addonTable.db.Leads[cleanName] then
                addonTable.QueueWhoSearch("n-"..cleanName)
            end
        end
        
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if not addonTable.db.Config.EnableAutoScanner then return end
        
        -- Do not scrape while in dungeons/instances or during combat
        local inInstance = IsInInstance()
        if inInstance or InCombatLockdown() or UnitAffectingCombat("player") then return end
        
        -- Do not scrape our own group members
        if UnitInParty(unit) or UnitInRaid(unit) then return end
        
        if UnitIsPlayer(unit) and UnitFactionGroup("player") == UnitFactionGroup(unit) then
            local guildName = GetGuildInfo(unit)
            if not guildName then
                local rawName = UnitName(unit)
                if not rawName or rawName == "Unknown" then return end
                
                -- Strip cross-realm tags to stay consistent with the database
                local name = strsplit("-", rawName)
                
                if not addonTable.RecentSearchResults then addonTable.RecentSearchResults = {} end
                addonTable.RecentSearchResults[name] = true
                
                if not addonTable.db.Leads[name] then
                    addonTable.db.Leads[name] = {
                        level = UnitLevel(unit),
                        class = UnitClassBase(unit),
                        status = "New",
                        timeSeen = time(),
                        source = "Proximity"
                    }
                    -- Auto-refresh the CRM search list
                    if addonTable.CRM and addonTable.CRM.UpdateSearchResults then
                        addonTable.CRM.UpdateSearchResults()
                    end
                else
                    addonTable.db.Leads[name].timeSeen = time()
                    addonTable.db.Leads[name].level = UnitLevel(unit)
                    addonTable.db.Leads[name].class = UnitClassBase(unit)
                    if addonTable.CRM and addonTable.CRM.UpdateSearchResults then
                        addonTable.CRM.UpdateSearchResults()
                    end
                end
            end
        end
    end
end)
