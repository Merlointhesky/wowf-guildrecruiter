# WoW Forever Beta Recruitment CRM Addon

## 1. Core Architecture
The addon functions as a lightweight CRM (Customer Relationship Management) tool tailored for in-game guild recruitment.

*   **CRM Dashboard (`/recruit`):** A custom UI frame acting as an applicant tracking system. Includes columns for Name, Level, Class, and Status (New, Interviewing, Waitlisted, Invited) alongside a free-text notes field.
*   **Database (`SavedVariables`):** Persistent storage of applicant profiles, blacklist status, and interaction history across login sessions.

## 2. Communications & Template Engine
Replaces manual typing with automated, categorized chat hooks.

*   **Quick-Reply Buttons:** Inline UI buttons next to player names to dispatch pre-written whispers.
*   **Templates:** Categorized messages for different pipeline stages (Greeting, Pitch, Rejection).
*   **Whisper Interception:** Hooks into the `CHAT_MSG_WHISPER` API event to flag players mentioning "lf guild" or "invite" as hot leads in the dashboard.

## 3. Broadcasts & Actions
*   **Trade Chat Announcer:** A UI button to broadcast recruitment pitches to public channels. Includes a 60-second hardware cooldown tracker to prevent accidental spamming and comply with Blizzard's automation rules.
*   **One-Click Invites:** Inline dashboard buttons executing `InviteUnit(playerName)`. Includes a pre-check via `GetGuildInfo(unit)` to ensure the target is unguilded.

## 4. Proximity Radar (Lead Generation)
Passively scans for unguilded players within 40-60 yards using nameplate events, dropping them into a "Nearby Leads" tab in the UI with [Whisper Pitch] and [Ignore] quick-actions.

### Radar Logic Flow
1. Listens for `NAME_PLATE_UNIT_ADDED`.
2. Verifies the unit is a friendly player via `UnitIsPlayer` and `UnitFactionGroup`.
3. Checks `GetGuildInfo(unit)`. If `nil`, captures Name, Class, and Level.
4. Populates the dashboard and prevents duplicate entries for players walking in and out of range.

### Core Scanner Implementation (Lua)
```lua
local ScannerFrame = CreateFrame("Frame")
ScannerFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

-- Table to hold the players we find
local NearbyUnguilded = {}

ScannerFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        -- 1. Ensure it's a player, not an NPC
        if UnitIsPlayer(unit) then
            
            -- 2. Ensure they are friendly (same faction)
            local myFaction = UnitFactionGroup("player")
            local theirFaction = UnitFactionGroup(unit)
            
            if myFaction == theirFaction then
                
                -- 3. Check for a guild tag
                local guildName = GetGuildInfo(unit)
                
                if not guildName then
                    local name = UnitName(unit)
                    local level = UnitLevel(unit)
                    local className = UnitClass(unit)
                    
                    -- 4. Avoid duplicates if they walk in and out of range
                    if not NearbyUnguilded[name] then
                        NearbyUnguilded[name] = {
                            level = level,
                            class = className,
                            timeSeen = time()
                        }
                        
                        -- Optional: Print to your chat frame so you know it worked
                        print("Found unguilded player: " .. name .. " (Level " .. level .. " " .. className .. ")")
                        
                        -- TODO: Trigger a function here to update CRM UI list
                    end
                end
            end
        end
    end
end)
```

## 5. Guild Sync & Officer Collaboration
A hybrid approach leveraging the Officer channel for both silent database syncing and visible alerts.

*   **Silent CRM Sync (Hidden):** Uses `C_ChatInfo.SendAddonMessage` with the `"OFFICER"` channel type to silently sync the CRM dashboard across all officers using the addon. If one officer marks a lead as "Waitlisted", everyone's UI updates instantly without spamming chat.
*   **Visible Action Alerts (Public):** Uses `SendChatMessage` to push formatted alerts to the `/o` (Officer) channel for major events. For example, if a player whispers to apply, or refuses an invite, the addon announces it: `[GuildRecruiter] Lead <PlayerName> declined invite. Reason: Has a guild.` This allows available officers to step in or stay informed without needing to constantly check the UI.

## 6. Advanced Lead Generation
Beyond the proximity radar, the addon employs active scanning techniques.

*   **Targeted `/Who` Scanning & Search Engine:** 
    *   **Automated Scanning:** Users define "Guild Needs" (e.g., Level 50+ Mages) and their faction. The addon automatically and periodically runs `/who` queries against major faction cities (respecting Blizzard rate limits) and parses the results.
    *   **Manual Queries:** Recruiters can input manual queries (e.g., searching "john" to find all Johns, or specific class/level ranges). 
    *   **Unguilded Toggle:** By default, the search engine filters out players who are already in a guild before dropping them into the CRM. A UI toggle allows users to disable this filter if they want to capture guilded players (e.g., for scouting or poaching).
*   **Smart Chat Parsing:** Hooks into `CHAT_MSG_CHANNEL` to monitor public channels (like LookingForGroup or General). If an unguilded player types keywords like "LFG" or "LFM", they are flagged as a high-value lead since they are actively playing the game.

## 7. Minimap Integration & Notifications
*   **Minimap Icon:** A standard minimap button using a default built-in WoW icon (like the guild tabard or a scroll). Clicking the icon toggles the main CRM Dashboard.
*   **Visual Alerts (Flashing):** When the addon intercepts a response to a recruitment whisper, the minimap icon will physically flash/pulse to alert the recruiter. This ensures that even if you are out in the world farming or not looking at your chat box, you never miss a lead's response.
*   **Session Stats Tooltip:** Hovering over the minimap icon displays a real-time summary of your current session's activity (resets upon relog). It tracks:
    *   Number of recruitment whispers sent.
    *   Number of responses received.
    *   Total number of new players who joined the guild.
    *   Number of new players who joined the guild *specifically* from your invites.

## 8. Data Management & Technical Requirements
To ensure the addon remains lightweight and complies with Blizzard's anti-spam rules, the following technical guardrails are implemented:

*   **Auto-Pruning (Configurable Slider):** To prevent database bloat, recruiters can set a retention slider for unengaged leads. Options include: 5 mins, 10 mins, 30 mins, 1 hour, 7 hours, 1 day, 3 days, and 7 days. If a lead doesn't respond within that window, they are cleared from the CRM. Blacklisted players are kept forever.
*   **Database Scoping:** Data is strictly scoped to the *current character* and their *current guild*. Since WoW Forever uses rulesets (Normal, PvP, RP, Hardcore) instead of traditional realms, this prevents cross-pollination of recruitment data if you play multiple characters across different rulesets.
*   **Bulk Whisper Queue & Throttling:** Recruiters can initiate a "Bulk Whisper" to a list of leads (e.g., from a `/who` scan). To prevent server disconnects, the addon places these in a hidden queue, automatically dispatching one whisper every 1.5 to 2 seconds.
*   **Verification (Closing the Loop):** The addon verifies an accepted invite by checking if the player is now listed in the Guild Roster or by validating their guild tag against the recruiter's guild.
*   **Alt Linking / Merge Profiles:** If a player responds on an alt (or says "whisper my main"), the UI allows the recruiter to associate the candidate's profile with a new character name. This merges their whisper history and updates the CRM target so follow-ups go to the correct character.

## 9. UI & Interaction Blueprint
The addon is divided into three primary user interfaces:

*   **1. The Minimap Icon**
    *   **Left-Click:** Toggles the Main CRM Window.
    *   **Right-Click:** Instantly opens the Configuration Pages.
    *   **Hover:** Displays the Session Stats Tooltip.
    *   **Visuals:** Flashes/pulses when a whisper response is intercepted.
*   **2. The Main Window (`/recruit`)**
    *   **Search Tab:** Interface for manual `/who` queries, displaying automated scan results, and the "Unguilded Only" filter toggle.
    *   **Candidates Tab (The CRM):** The main roster of leads. Includes the free-text notes field, the Bulk-Whisper initiation button, and inline quick actions per player (Invite, Blacklist, Link Alt, and the Template Message Dropdown).
*   **3. Configuration Pages (`/recruit config`)**
    *   **Templates:** Inputs for 3 Trade Campaign messages and 5 Whisper Templates.
    *   **Targeting & Scanners:** Checkboxes to define "Guild Needs" (Classes/Levels), toggles to enable/disable background scanners (Proximity, Auto-Who, Chat Parsing), and a dropdown to select the target channel for Broadcasts.
    *   **Data Management:** The configurable data retention slider (5m to 7d).

## 10. WoW Forever Beta (v1.60.1) API Constraints
To ensure compatibility with the current Beta environment, all code will strictly adhere to the following technical contexts:

*   **Modern API Architecture:** *WoW: Forever* does **not** use the legacy Classic API. It runs on the modern Retail/Midnight-era engine (Custom Lua 5.1). We must use modern namespaces (e.g., `C_FriendList.SendWho()`, `C_GuildInfo`) instead of legacy global functions.
*   **Realmless Scoping:** Since traditional servers are replaced by rulesets (Normal, PvP, Hardcore, RP), our `SavedVariables` will map data securely via `[Ruleset][Faction]` to avoid cross-pollination.
*   **SavedVariables Beta Bug Workaround:** A known bug in the beta prevents `SavedVariables` from persisting on logout. The addon will implement a local manual serialization workaround (or integrate with `ForeverSVFix`) to ensure your CRM database is safely stored between sessions.
*   **UI Modernization Context:** The visual components (Minimap, CRM frames) will be styled to match the new native UI consolidations introduced in *Forever*, minimizing dependency on legacy visual frameworks.

## 11. Guild Members Cache & Management
To better track the evolution of the guild roster, a new **Members** tab will be added to the Main Window (`/recruit`). This tab acts as a cached ledger of your guild's roster across sessions.

### Core Features
*   **Roster Snapshotting:** Upon login or roster updates (`GUILD_ROSTER_UPDATE`), the addon caches the current guild members (Name, Class, Level, Public Note, Officer Note, and Rank) into the `SavedVariables` database for the current guild.
*   **Delta Tracking & Status:** By comparing the live roster against the last cached snapshot, members are categorized as:
    *   **New:** Joined the guild since the player's last login.
    *   **Leaver:** Present in the cached database, but no longer in the live roster. These entries persist until manually cleared by the user.
    *   **Existing:** Present in both the live roster and the cached snapshot.
*   **Level Up Detection:** If an existing member's live level is higher than their cached level, the UI will highlight their growth (e.g., displaying `20 (+2)`).
*   **Inline Management:** The UI will provide inline controls to manage members directly from the tab (respecting the user's guild permissions):
    *   **Notes:** Editable fields for both Public Notes (`GuildRosterSetPublicNote` or API equivalent) and Officer Notes (`GuildRosterSetOfficerNote`).
    *   **Rank Controls:** Quick action buttons for promoting or demoting members (`GuildPromote` / `GuildDemote`).
*   **Permissions Handling:** The UI will dynamically check permissions (e.g., `CanEditPublicNote()`, `CanGuildPromote()`) to enable or disable these management buttons appropriately.

### Advanced Management
*   **Inactivity Tracking & Purging:** The cache will capture the "Last Online" data provided by the API. The UI will feature an "Inactive" filter (e.g., highlighting players offline for >30 days) and a "Purge Inactive" button to easily view and batch-remove stagnant roster entries.
*   **Main-Alt Linking:** To help solve alt tracking, officers can link character profiles together within the cache. Right-clicking a member will allow them to "Link to Main," which will group them visually in the CRM and optionally format their note to indicate the linkage (e.g., `[Alt: MainName]`).