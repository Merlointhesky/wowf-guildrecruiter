-- Core addon namespace and initialization
local addonName, addonTable = ...
_G[addonName] = addonTable



function addonTable.DebugLog(msg)
    local timestamp = date("%m/%d/%y %H:%M:%S")
    local logString = "[" .. timestamp .. "] " .. tostring(msg)
    
    if addonTable.db and addonTable.db.Config and addonTable.db.Config.EnableDebug then
        print("|cFF999999[GR Debug]|r " .. tostring(msg))
    end
    
    -- Save to internal log table for the developer to read from disk
    if type(GuildRecruiterDebugLog) == "table" then
        table.insert(GuildRecruiterDebugLog, logString)
        -- Keep log from growing infinitely
        if #GuildRecruiterDebugLog > 500 then
            table.remove(GuildRecruiterDebugLog, 1)
        end
    end
end

addonTable.Events = CreateFrame("Frame")

addonTable.Events:RegisterEvent("ADDON_LOADED")
addonTable.Events:RegisterEvent("PLAYER_LOGIN")
addonTable.Events:RegisterEvent("GUILD_ROSTER_UPDATE")

addonTable.Events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            -- Initialize Debug Log
            if type(GuildRecruiterDebugLog) ~= "table" then
                GuildRecruiterDebugLog = {}
            end
            addonTable.DebugLog("=== Addon Loaded ===")

            -- Initialize Database when the addon's saved variables are loaded
            if addonTable.Database_OnInit then
                addonTable.Database_OnInit()
            end
            
            -- Load saved minimap icon angle
            if addonTable.LoadMinimapPosition then
                addonTable.LoadMinimapPosition()
            end
        end
    elseif event == "PLAYER_LOGIN" then
        print("|cFF00FF00[Guild Recruiter]|r loaded! Type /recruit to open the CRM.")
        if IsInGuild() then
            if C_GuildInfo and C_GuildInfo.GuildRoster then
                C_GuildInfo.GuildRoster()
            elseif GuildRoster then
                GuildRoster()
            end
        end
    elseif event == "GUILD_ROSTER_UPDATE" then
        if addonTable.SnapshotRoster then
            addonTable.SnapshotRoster()
        end
    end
end)

-- Slash command to open the UI
SLASH_GUILDRECRUITER1 = "/recruit"
SlashCmdList["GUILDRECRUITER"] = function(msg)
    if msg == "config" then
        if addonTable.ToggleConfigWindow then
            addonTable.ToggleConfigWindow()
        end
    else
        -- Toggle main window
        if addonTable.ToggleMainWindow then
            addonTable.ToggleMainWindow()
        end
    end
end

