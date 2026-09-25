local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")
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

-- Returns line1 (name-realm + class + faction), line2 (availability/typing + zone),
-- and the status dot color key. Both lines are "" when there is no contact.
function StatusLine.Build(selectedContact, status)
  if not selectedContact then
    return "", "", nil
  end

  local line1 = {}

  if selectedContact.realmName and selectedContact.realmName ~= "" then
    local name = selectedContact.name or selectedContact.displayName or ""
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

  if selectedContact.className and selectedContact.className ~= "" then
    table.insert(line1, Localization.Text(selectedContact.className))
  end

  -- Show faction (inferred from race, or direct from BNet API)
  local factionName = selectedContact.factionName
  if factionName and factionName ~= "" then
    table.insert(line1, Localization.Text(factionName))
  end

  local line2 = {}
  local dotColor = nil

  -- A live typing indicator replaces the availability label while it lasts.
  local statusKey = status and status.status or nil
  local avail = statusKey and StatusLine.AVAILABILITY_DISPLAY[statusKey] or nil
  if selectedContact.isTyping then
    table.insert(line2, Localization.Text("typing…"))
    dotColor = "online"
  elseif avail then
    table.insert(line2, Localization.Text(avail.label))
    local seenLabel = statusKey == "Offline" and lastSeenLabel(selectedContact) or nil
    if seenLabel then
      table.insert(line2, seenLabel)
    end
    dotColor = avail.color
  end

  if selectedContact.areaName and selectedContact.areaName ~= "" then
    table.insert(line2, selectedContact.areaName)
  end

  local sep = "  -  "
  return table.concat(line1, sep), table.concat(line2, sep), dotColor
end

ns.ConversationPaneStatusLine = StatusLine

return StatusLine
