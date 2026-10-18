local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local LevelColor = ns.LevelColor or require("WhisperMessenger.UI.LevelColor")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local StatusLine = {}

StatusLine.AVAILABILITY_DISPLAY = {
  CanWhisper = { label = "Online", color = "online" },
  XFaction = { label = "X-Faction", color = "online" },
  Away = { label = "Away", color = "away" },
  Busy = { label = "Busy", color = "dnd" },
  BNetOnline = { label = "Online (App)", color = "away" },
  Offline = { label = "Offline", color = "offline" },
  Unavailable = { label = "Unavailable", color = "offline" },
  WrongFaction = { label = "Wrong Faction", color = "dnd" },
  ["Mythic Lockdown"] = { label = "Mythic Lockdown", color = "dnd" },
  ["Competitive Content"] = { label = "Competitive Content", color = "dnd" },
  ["Send unavailable"] = { label = "Send unavailable", color = "dnd" },
  ["Send failed"] = { label = "Send failed", color = "dnd" },
}

-- "Last online 2h" for Battle.net friends (Blizzard's time, nil while
-- online), else "Last seen 2h" from the newest of our own last-seen stamp and
-- the last whisper they sent. nil when no time is known.
local function lastSeenLabel(selectedContact)
  -- The relative text needs the game clock.
  if type(_G.time) ~= "function" then
    return nil
  end
  if selectedContact.channel == "BN" and tonumber(selectedContact.lastOnlineTime) then
    return string.format(Localization.Text("Last online %s"), TimeFormat.ContactPreview(selectedContact.lastOnlineTime))
  end
  local conversation = selectedContact.conversation or {}
  local seenAt = math.max(tonumber(conversation.lastSeenAt) or 0, tonumber(conversation.lastIncomingAt) or 0)
  if seenAt <= 0 then
    return nil
  end
  return string.format(Localization.Text("Last seen %s"), TimeFormat.ContactPreview(seenAt))
end

-- The live zone, else the last /who zone with its age (second return true).
-- A guid-less chat never gets a real check, so its Offline is only a default:
-- the zone shows, and the caller drops that Offline label.
local function zoneText(selectedContact, statusKey)
  if selectedContact.areaName and selectedContact.areaName ~= "" then
    return selectedContact.areaName, false
  end
  if not selectedContact.whoArea or selectedContact.whoArea == "" then
    return nil
  end
  if selectedContact.guid and statusKey == "Offline" then
    return nil
  end

  return selectedContact.whoArea .. " (" .. TimeFormat.ContactPreview(selectedContact.whoAreaAt) .. ")", true
end

-- "Level 80 Orc Shaman": level, race and class in one chunk. Only the level
-- takes the difficulty colour, and only with the option on. The race comes
-- already translated by the game. Returns the chunk (nil when all three are
-- unknown) and whether the race made it in.
local function classChunk(selectedContact)
  local parts = {}
  local level = DisplayName.ShowPlayerLevels() and tonumber(selectedContact.characterLevel)
  if level then
    table.insert(parts, LevelColor.Escape(level) .. string.format(Localization.Text("Level %d"), level) .. "|r")
  end
  local race = selectedContact.raceName
  local raceShown = not SecretValue.Is(race) and type(race) == "string" and race ~= ""
  if raceShown then
    table.insert(parts, race)
  end
  local className = selectedContact.className
  if className and className ~= "" then
    table.insert(parts, Localization.Text(className))
  end
  if #parts == 0 then
    return nil, false
  end
  return table.concat(parts, " "), raceShown
end

-- Returns line1 (name-realm + class + faction), line2 (availability/typing + zone),
-- and the status dot color key. Both lines are "" when there is no contact.
function StatusLine.Build(selectedContact, status)
  if not selectedContact then
    return "", "", nil
  end

  local line1 = {}

  if selectedContact.realmName and selectedContact.realmName ~= "" then
    local name = selectedContact.name or DisplayName.Format(selectedContact.displayName) or ""
    if name ~= "" then
      table.insert(line1, name .. "-" .. selectedContact.realmName)
    else
      table.insert(line1, selectedContact.realmName)
    end
  elseif selectedContact.characterName and selectedContact.characterName ~= "" then
    local realm = selectedContact.realm or ""
    if realm ~= "" then
      table.insert(line1, selectedContact.characterName .. "-" .. realm)
    else
      table.insert(line1, selectedContact.characterName)
    end
  end

  local chunk, raceShown = classChunk(selectedContact)
  if chunk then
    table.insert(line1, chunk)
  end

  -- Show faction (inferred from race, or direct from BNet API). With the race
  -- shown, the faction icon next to the name already says it.
  local factionName = selectedContact.factionName
  local iconSaysFaction = raceShown and Theme.FactionIcon(factionName) ~= nil
  if factionName and factionName ~= "" and not iconSaysFaction then
    table.insert(line1, Localization.Text(factionName))
  end

  local line2 = {}
  local dotColor = nil

  if selectedContact.isBlocked then
    table.insert(line2, UIHelpers.colorEscape(Theme.COLORS.danger_text) .. Localization.Text("Blocked") .. "|r")
  end

  -- A live typing indicator replaces the availability label while it lasts.
  local statusKey = status and status.status or nil
  local zone, isWhoZone = zoneText(selectedContact, statusKey)
  local avail = statusKey and StatusLine.AVAILABILITY_DISPLAY[statusKey] or nil
  if selectedContact.isTyping then
    table.insert(line2, Localization.Text("typing…"))
    dotColor = "online"
  elseif avail then
    -- The zone replaces a default Offline, its Last seen and its grey dot.
    if not (isWhoZone and statusKey == "Offline") then
      dotColor = avail.color
      table.insert(line2, Localization.Text(avail.label))
      local seenLabel = statusKey == "Offline" and lastSeenLabel(selectedContact) or nil
      if seenLabel then
        table.insert(line2, seenLabel)
      end
    end
  end

  if zone then
    table.insert(line2, zone)
  end

  local sep = "  -  "
  return table.concat(line1, sep), table.concat(line2, sep), dotColor
end

ns.ConversationPaneStatusLine = StatusLine

return StatusLine
