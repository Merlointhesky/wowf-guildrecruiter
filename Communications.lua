local addonName, addonTable = ...
local Comms = CreateFrame("Frame")
addonTable.Comms = Comms

Comms:RegisterEvent("CHAT_MSG_WHISPER")
Comms:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
Comms:RegisterEvent("CHAT_MSG_SYSTEM")
Comms:RegisterEvent("CHAT_MSG_AFK")
Comms:RegisterEvent("CHAT_MSG_DND")
Comms:RegisterEvent("CHAT_MSG_ADDON")

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix("GR_SYNC")
elseif RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix("GR_SYNC")
end

local HistoryQueue = {}
local CombatFrame = CreateFrame("Frame")
CombatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
CombatFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        for _, pName in ipairs(HistoryQueue) do
            if addonTable.ShowHistory then addonTable.ShowHistory(pName) end
        end
        wipe(HistoryQueue)
    end
end)

local function QueueOrShowHistory(playerName)
    if InCombatLockdown() then
        local found = false
        for _, name in ipairs(HistoryQueue) do
            if name == playerName then found = true; break end
        end
        if not found then
            table.insert(HistoryQueue, playerName)
        end
    else
        if addonTable.ShowHistory then addonTable.ShowHistory(playerName) end
    end
end

StaticPopupDialogs["GR_ACCEPT_INVITE"] = {
    text = "%s wants to join the guild, do you want to invite them?",
    button1 = "Invite",
    button2 = "Cancel",
    OnAccept = function(self, data)
        addonTable.InviteLead(data)
        if addonTable.db.Leads[data] then
            addonTable.db.Leads[data].status = "Joined"
        end
        if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
        if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["GR_DECLINE_ACTION"] = {
    text = "%s declined. What do you want to do?",
    button1 = "Blacklist",
    button2 = "Cancel",
    button3 = "Remove",
    OnAccept = function(self, data)
        if addonTable.db.Leads[data] then
            addonTable.db.Leads[data].status = "Blacklisted"
            addonTable.db.Blacklist[data] = true
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
        end
    end,
    OnCancel = function(self, data, reason)
        -- Cancel button clicked
    end,
    OnAlt = function(self, data)
        -- Remove button clicked
        if addonTable.db.Leads[data] then
            addonTable.db.Leads[data] = nil
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Bulk Whisper Queue
local whisperQueue = {}
local isBulkWhispering = false
local timeSinceLastWhisper = 0
local WHISPER_INTERVAL = 1.5 -- Seconds

-- Session Stats tracking
addonTable.SessionStats = {
    whispersSent = 0,
    responses = 0,
    totalJoined = 0,
    invitedJoined = 0
}

function addonTable.QueueBulkWhisper(playerName, message)
    table.insert(whisperQueue, {name = playerName, msg = message})
    if not isBulkWhispering then
        isBulkWhispering = true
        Comms:SetScript("OnUpdate", Comms.ProcessWhisperQueue)
    end
end

function Comms:ProcessWhisperQueue(elapsed)
    timeSinceLastWhisper = timeSinceLastWhisper + elapsed
    
    if timeSinceLastWhisper >= WHISPER_INTERVAL then
        timeSinceLastWhisper = 0
        
        if #whisperQueue > 0 then
            local nextWhisper = table.remove(whisperQueue, 1)
            SendChatMessage(nextWhisper.msg, "WHISPER", nil, nextWhisper.name)
            addonTable.SessionStats.whispersSent = addonTable.SessionStats.whispersSent + 1
            
            -- History is now entirely handled automatically by CHAT_MSG_WHISPER_INFORM
        else
            isBulkWhispering = false
            Comms:SetScript("OnUpdate", nil)
        end
    end
end

-- Broadcast to Trade/LFG
local lastBroadcastTime = 0
local BROADCAST_COOLDOWN = 60
local currentCampaignIndex = 1

function addonTable.BroadcastCampaign()
    if time() - lastBroadcastTime < BROADCAST_COOLDOWN then
        print("|cFFFF0000[Guild Recruiter]|r Broadcast on cooldown. Wait " .. (BROADCAST_COOLDOWN - (time() - lastBroadcastTime)) .. " seconds.")
        return
    end
    
    local campaigns = addonTable.db.Config.Campaigns or {}
    local validCampaigns = {}
    for _, c in ipairs(campaigns) do
        if c and c ~= "" then table.insert(validCampaigns, c) end
    end
    if #validCampaigns == 0 then table.insert(validCampaigns, "Looking for more!") end
    
    if currentCampaignIndex > #validCampaigns then currentCampaignIndex = 1 end
    
    local msg = validCampaigns[currentCampaignIndex]
    local channel = addonTable.db.Config.BroadcastChannel or 2 -- Default 2 is Trade
    
    SendChatMessage(msg, "CHANNEL", nil, channel)
    lastBroadcastTime = time()
    
    currentCampaignIndex = currentCampaignIndex + 1
end

-- Invite Player
function addonTable.InviteLead(playerName)
    if C_GuildInfo and C_GuildInfo.Invite then
        C_GuildInfo.Invite(playerName)
    else
        GuildInvite(playerName)
    end
end

function addonTable.SyncStatus(playerName, status)
    if not IsInGuild() then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage("GR_SYNC", "STATUS:" .. playerName .. ":" .. status, "GUILD")
    elseif SendAddonMessage then
        SendAddonMessage("GR_SYNC", "STATUS:" .. playerName .. ":" .. status, "GUILD")
    end
end

function addonTable.SyncAlt(altName, mainName)
    if not IsInGuild() then return end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage("GR_SYNC", "ALT:" .. altName .. ":" .. mainName, "GUILD")
    elseif SendAddonMessage then
        SendAddonMessage("GR_SYNC", "ALT:" .. altName .. ":" .. mainName, "GUILD")
    end
end

local function containsWord(text, word)
    return string.match(" " .. text .. " ", "%W" .. word .. "%W") ~= nil
end

local function GetSafeString(msg)
    local success, str = pcall(tostring, msg)
    if not success then return nil end
    local success2 = pcall(string.match, str, "")
    if not success2 then return nil end
    return str
end

function addonTable.DetermineResponseStatus(msg)
    local safeMsg = GetSafeString(msg)
    if not safeMsg then return nil end
    local lowerMsg = string.lower(safeMsg)
    
    local isDecline = containsWord(lowerMsg, "no") or
                      containsWord(lowerMsg, "no thanks") or
                      containsWord(lowerMsg, "no thank you") or
                      containsWord(lowerMsg, "no ty") or
                      containsWord(lowerMsg, "no thx") or
                      containsWord(lowerMsg, "nty") or
                      containsWord(lowerMsg, "nah") or
                      containsWord(lowerMsg, "nope") or
                      containsWord(lowerMsg, "pass") or
                      containsWord(lowerMsg, "i'll pass") or
                      containsWord(lowerMsg, "not interested") or
                      (containsWord(lowerMsg, "not") and not containsWord(lowerMsg, "why not")) or
                      containsWord(lowerMsg, "im good") or
                      containsWord(lowerMsg, "i'm good") or
                      containsWord(lowerMsg, "already") or
                      containsWord(lowerMsg, "thanks for the invite") or
                      containsWord(lowerMsg, "thank you for the invite")
                      
    local isAccept =  containsWord(lowerMsg, "yes") or
                      containsWord(lowerMsg, "ok") or
                      containsWord(lowerMsg, "okay") or
                      containsWord(lowerMsg, "sure") or
                      containsWord(lowerMsg, "yeah") or
                      containsWord(lowerMsg, "yea") or
                      containsWord(lowerMsg, "yep") or
                      containsWord(lowerMsg, "why not") or
                      containsWord(lowerMsg, "inv") or
                      containsWord(lowerMsg, "invite")

    if isDecline then return "Denied" end
    if isAccept then return "Accepted" end
    return nil
end

Comms:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        msg = GetSafeString(msg)
        if not msg then return end
        local cleanName = strsplit("-", sender)
        
        -- If we have them as a lead, this is a response!
        if addonTable.db.Leads[cleanName] then
            if addonTable.db.Leads[cleanName].status ~= "Joined" and addonTable.db.Leads[cleanName].status ~= "Blacklisted" then
                addonTable.SessionStats.responses = addonTable.SessionStats.responses + 1
                
                local detectedStatus = addonTable.DetermineResponseStatus(msg)
                
                if detectedStatus == "Denied" then
                    addonTable.db.Leads[cleanName].status = "Denied"
                    addonTable.SyncStatus(cleanName, "Denied")
                    QueueOrShowHistory(cleanName)
                elseif detectedStatus == "Accepted" then
                    addonTable.db.Leads[cleanName].status = "Accepted"
                    addonTable.db.Leads[cleanName].hidden = nil
                    addonTable.SyncStatus(cleanName, "Accepted")
                    QueueOrShowHistory(cleanName)
                else
                    addonTable.db.Leads[cleanName].status = "Interviewing"
                    addonTable.db.Leads[cleanName].hidden = nil
                    addonTable.SyncStatus(cleanName, "Interviewing")
                end
            end
            
            -- Store whisper in history
            if not addonTable.db.Leads[cleanName].whisperHistory then
                addonTable.db.Leads[cleanName].whisperHistory = {}
            end
            table.insert(addonTable.db.Leads[cleanName].whisperHistory, {
                direction = "in",
                text = msg,
                timestamp = time(),
            })
            
            -- Trigger minimap flash
            if addonTable.TriggerMinimapFlash then
                addonTable.TriggerMinimapFlash()
            end
            
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then
                addonTable.CRM.UpdateCandidateList()
            end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then
                addonTable.CRM.UpdateSearchResults()
            end
            
            if addonTable.UpdateHistoryIfOpen then
                addonTable.UpdateHistoryIfOpen(cleanName)
            end
        elseif addonTable.GetMembersDB() and addonTable.GetMembersDB()[cleanName] then
            if not addonTable.GetMembersDB()[cleanName].whisperHistory then
                addonTable.GetMembersDB()[cleanName].whisperHistory = {}
            end
            table.insert(addonTable.GetMembersDB()[cleanName].whisperHistory, {
                direction = "in",
                text = msg,
                timestamp = time(),
            })
            
            if addonTable.UpdateHistoryIfOpen then
                addonTable.UpdateHistoryIfOpen(cleanName)
            end
        end
        
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        local msg, target = ...
        msg = GetSafeString(msg)
        if not msg then return end
        local cleanName = strsplit("-", target)
        
        -- Removed auto-add for outgoing whispers to prevent randoms/guildies from being added to CRM
        
        if addonTable.db.Leads[cleanName] then
            -- If we just manually whispered them, mark them as pitched if they were New
            if addonTable.db.Leads[cleanName].status == "New" then
                addonTable.db.Leads[cleanName].status = "Pitched"
                addonTable.db.Leads[cleanName].claimedBy = UnitName("player")
                addonTable.SyncStatus(cleanName, "Pitched")
            end
            
            -- Store our outgoing manual whisper in history
            if not addonTable.db.Leads[cleanName].whisperHistory then
                addonTable.db.Leads[cleanName].whisperHistory = {}
            end
            table.insert(addonTable.db.Leads[cleanName].whisperHistory, {
                direction = "out",
                text = msg,
                timestamp = time(),
            })
            
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
            
            if addonTable.UpdateHistoryIfOpen then
                addonTable.UpdateHistoryIfOpen(cleanName)
            end
        elseif addonTable.GetMembersDB() and addonTable.GetMembersDB()[cleanName] then
            if not addonTable.GetMembersDB()[cleanName].whisperHistory then
                addonTable.GetMembersDB()[cleanName].whisperHistory = {}
            end
            table.insert(addonTable.GetMembersDB()[cleanName].whisperHistory, {
                direction = "out",
                text = msg,
                timestamp = time(),
            })
            
            if addonTable.UpdateHistoryIfOpen then
                addonTable.UpdateHistoryIfOpen(cleanName)
            end
        end
        
    elseif event == "CHAT_MSG_AFK" or event == "CHAT_MSG_DND" then
        local msg, sender = ...
        msg = GetSafeString(msg)
        if not msg then return end
        local cleanName = strsplit("-", sender)
        
        if addonTable.db.Leads[cleanName] then
            addonTable.db.Leads[cleanName].status = event == "CHAT_MSG_AFK" and "AFK" or "DND"
            
            if not addonTable.db.Leads[cleanName].whisperHistory then
                addonTable.db.Leads[cleanName].whisperHistory = {}
            end
            table.insert(addonTable.db.Leads[cleanName].whisperHistory, {
                direction = "in",
                text = "<" .. (event == "CHAT_MSG_AFK" and "AFK" or "DND") .. "> " .. msg,
                timestamp = time(),
            })
            
            if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
            if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
        end
        
    elseif event == "CHAT_MSG_SYSTEM" then
        local msg = ...
        msg = GetSafeString(msg)
        if not msg then return end
        -- Hooking guild joins: "Player has joined the guild."
        local joinedPlayer = string.match(msg, "^(.-) has joined the guild%.")
        if joinedPlayer then
            addonTable.SessionStats.totalJoined = addonTable.SessionStats.totalJoined + 1
            
            if addonTable.db.Config.EnableAutoWelcome then
                local welcomeMsg = addonTable.db.Config.WelcomeMessage or ""
                if welcomeMsg ~= "" then
                    StaticPopup_Show("GR_WELCOME_GUILD", joinedPlayer, nil, joinedPlayer)
                end
                
                local infoMsg = addonTable.db.Config.WelcomeInfoMessage or ""
                if infoMsg ~= "" then
                    infoMsg = string.gsub(infoMsg, "%%[tT]", joinedPlayer)
                    C_Timer.After(3.0, function() 
                        local lines = {strsplit("\n", infoMsg)}
                        for i, line in ipairs(lines) do
                            local cleanLine = strtrim(line)
                            if cleanLine ~= "" then
                                C_Timer.After((i-1) * 0.5, function()
                                    SendChatMessage(cleanLine, "WHISPER", nil, joinedPlayer)
                                end)
                            end
                        end
                    end)
                end
            end
            
            if addonTable.db.Leads[joinedPlayer] then
                addonTable.db.Leads[joinedPlayer].status = "Joined"
                addonTable.SyncStatus(joinedPlayer, "Joined")
                addonTable.SessionStats.invitedJoined = addonTable.SessionStats.invitedJoined + 1
                
                if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
                if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
            end
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        if prefix == "GR_SYNC" then
            local action, targetName, data1 = strsplit(":", message)
            local cleanSender = strsplit("-", sender)
            if cleanSender == UnitName("player") then return end
            
            if action == "STATUS" and targetName and data1 then
                if data1 == "Blacklisted" then
                    addonTable.db.Blacklist[targetName] = true
                    if not addonTable.db.Leads[targetName] then
                        addonTable.db.Leads[targetName] = { timeSeen = time(), status = "Blacklisted" }
                    else
                        addonTable.db.Leads[targetName].status = "Blacklisted"
                        addonTable.db.Leads[targetName].claimedBy = cleanSender
                    end
                    if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
                    if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
                elseif addonTable.db.Leads[targetName] then
                    addonTable.db.Leads[targetName].status = data1
                    addonTable.db.Leads[targetName].claimedBy = cleanSender
                    addonTable.db.Leads[targetName].hidden = nil
                    
                    if addonTable.CRM and addonTable.CRM.UpdateCandidateList then addonTable.CRM.UpdateCandidateList() end
                    if addonTable.CRM and addonTable.CRM.UpdateSearchResults then addonTable.CRM.UpdateSearchResults() end
                end
            elseif action == "ALT" and targetName and data1 then
                if addonTable.GetMembersDB() and addonTable.GetMembersDB()[targetName] then
                    addonTable.GetMembersDB()[targetName].mainLink = data1
                    if addonTable.CRM and addonTable.CRM.UpdateMembersList then addonTable.CRM.UpdateMembersList() end
                end
            end
        end
    end
end)

StaticPopupDialogs["GR_WELCOME_GUILD"] = {
    text = "%s has joined the guild! Send welcome message?",
    button1 = "Welcome",
    button2 = "Cancel",
    OnAccept = function(self, data)
        local welcomeMsg = addonTable.db.Config.WelcomeMessage or ""
        if welcomeMsg ~= "" and data then
            welcomeMsg = string.gsub(welcomeMsg, "%%[tT]", data)
            SendChatMessage(welcomeMsg, "GUILD")
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
