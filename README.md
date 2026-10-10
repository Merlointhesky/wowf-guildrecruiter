# Guild Recruiter

**Version:** 1.0.0  
**WoW Version:** WoW Forever Beta (v1.60.1)  
**Interface:** `16001`  

## Description
A lightweight CRM (Customer Relationship Management) and lead generation tool tailored for in-game guild recruitment in WoW Forever Beta.

## Features
- **CRM Dashboard (`/recruit`):** An applicant tracking system with columns for Name, Level, Class, Status, and notes. Accessible via chat command or Minimap icon.
- **Communications & Templates:** Inline quick-reply buttons and categorized chat templates.
- **Broadcasts & Actions:** Trade Chat announcer with cooldown tracking and one-click unguilded invites.
- **Proximity Radar:** Passively scans for unguilded players within 40-60 yards and adds them to a "Nearby Leads" tab.
- **Guild Sync & Officer Collaboration:** Silently syncs CRM data across officers using the hidden officer channel, and pushes formatted alerts to `/o` for major events.
- **Advanced Lead Generation:** Automated `/who` scanning based on "Guild Needs" and smart chat parsing to detect players typing "LFG" or "LFM".
- **Members Cache & Management:** A dedicated tab tracking the live roster vs. cached snapshot to easily identify new joins, leavers, and inactive members. Includes inline controls for notes and ranks.

## Important Note for WoW Forever Beta
Due to a known beta bug preventing `SavedVariables` from persisting on logout, this addon implements a local manual serialization workaround to ensure your CRM database is safely stored between sessions. Data is strictly scoped to your current character and guild to prevent cross-pollination across rulesets.
