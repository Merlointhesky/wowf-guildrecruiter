local addonName, addonTable = ...

function addonTable.Database_OnInit()
    -- Initialize the global saved variable if it doesn't exist
    if not GuildRecruiterDB then
        GuildRecruiterDB = {}
    end

    -- Scope the database by Realm (or Ruleset in WoW Forever) and Faction
    local realm = GetRealmName()
    local faction = UnitFactionGroup("player")
    local playerName = UnitName("player")

    if not GuildRecruiterDB[realm] then
        GuildRecruiterDB[realm] = {}
    end

    if not GuildRecruiterDB[realm][faction] then
        GuildRecruiterDB[realm][faction] = {}
    end
    
    -- The actual scoped database reference we will use throughout the addon
    addonTable.db = GuildRecruiterDB[realm][faction]

    -- Set up default table structures if this is a fresh install for this realm/faction
    if not addonTable.db.Leads then addonTable.db.Leads = {} end
    if not addonTable.db.Blacklist then addonTable.db.Blacklist = {} end
    
    if not addonTable.db.Config then
        addonTable.db.Config = {
            RetentionTime = 86400, -- Default 1 day in seconds
            EnableAutoScanner = true,
            EnableAutoWho = true,
            EnableChatParser = true,
            FilterGuilded = true,
            BroadcastChannel = 2, -- Default Trade
        }
    end
    -- Data Pruning Function
    local retention = addonTable.db.Config.RetentionTime or 86400
    local currentTime = time()
    for name, data in pairs(addonTable.db.Leads) do
        -- Never prune blacklisted or joined members
        if data.status ~= "Blacklisted" and data.status ~= "Joined" then
            if data.timeSeen and (currentTime - data.timeSeen > retention) then
                addonTable.db.Leads[name] = nil
            end
        end
    end

    print("GuildRecruiter Database initialized and pruned for " .. realm .. " - " .. faction)
end

function addonTable.GetMembersDB()
    local guildName = GetGuildInfo("player")
    if not guildName then
        return nil
    end
    
    if not addonTable.db.Guilds then
        addonTable.db.Guilds = {}
    end
    
    if not addonTable.db.Guilds[guildName] then
        addonTable.db.Guilds[guildName] = { Members = {} }
        
        -- Migrate legacy data
        if addonTable.db.Members and next(addonTable.db.Members) then
            addonTable.db.Guilds[guildName].Members = addonTable.db.Members
            addonTable.db.Members = nil
        end
    end
    
    return addonTable.db.Guilds[guildName].Members
end

function addonTable.SnapshotRoster()
    if not IsInGuild() then return end
    
    local membersDB = addonTable.GetMembersDB()
    if not membersDB then return end
    
    local numMembers = GetNumGuildMembers()
    local currentMembers = {}
    
    for i = 1, numMembers do
        local name, rankName, rankIndex, level, classDisplayName, zone, publicNote, officerNote, isOnline, status, class, achievementPoints, achievementRank, isMobile, canSojourn, repStanding, guid = GetGuildRosterInfo(i)
        if name then
            name = strsplit("-", name) -- Remove realm suffix
            currentMembers[name] = true
            
            local oldData = membersDB[name]
            local isNew = false
            local oldLevel = level
            
            if not oldData then
                isNew = true
            else
                oldLevel = oldData.level or level
            end
            
            -- Estimate last online time
            local lastOnlineTime = time()
            if not isOnline then
                if GetGuildRosterLastOnline then
                    local years, months, days, hours = GetGuildRosterLastOnline(i)
                    if (years and years > 0) or (months and months > 0) or (days and days > 0) or (hours and hours > 0) then
                        local offlineSecs = ((years or 0) * 365 + (months or 0) * 30 + (days or 0)) * 86400 + (hours or 0) * 3600
                        lastOnlineTime = time() - offlineSecs
                    elseif oldData and oldData.lastOnlineTime then
                        lastOnlineTime = oldData.lastOnlineTime
                    end
                elseif oldData and oldData.lastOnlineTime then
                    lastOnlineTime = oldData.lastOnlineTime
                end
            end
            
            membersDB[name] = {
                name = name,
                class = class,
                classDisplayName = classDisplayName,
                level = level,
                oldLevel = oldLevel,
                rankIndex = rankIndex,
                rankName = rankName,
                publicNote = publicNote,
                officerNote = officerNote,
                isNew = isNew,
                isLeaver = false,
                isOnline = isOnline,
                lastOnlineTime = lastOnlineTime,
                rosterIndex = i,
                guid = guid,
                mainLink = oldData and oldData.mainLink or nil
            }
        end
    end
    
    -- Identify leavers
    for name, data in pairs(membersDB) do
        if not currentMembers[name] then
            data.isLeaver = true
        end
    end
    
    if addonTable.CRM and addonTable.CRM.UpdateMembersList then
        addonTable.CRM.UpdateMembersList()
    end
end
