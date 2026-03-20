local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local StatusLine = {}

StatusLine.AVAILABILITY_DISPLAY = {
  CanWhisper = { label = "Online", color = "online" },
  CanWhisperGuild = { label = "Online", color = "online" },
  Offline = { label = "Offline", color = "offline" },
  WrongFaction = { label = "Wrong Faction", color = "offline" },
  Lockdown = { label = "Unavailable", color = "dnd" },
}

function StatusLine.Build(selectedContact, status)
  if not selectedContact then
    return "", nil
  end

  local parts = {}
  local dotColor = nil

  -- Availability status from the game API
  local statusKey = status and status.status or nil
  local avail = statusKey and StatusLine.AVAILABILITY_DISPLAY[statusKey] or nil
  if avail then
    table.insert(parts, avail.label)
    dotColor = avail.color
  end

  if selectedContact.realmName and selectedContact.realmName ~= "" then
    local name = selectedContact.name or selectedContact.displayName or ""
    if name ~= "" then
      table.insert(parts, name .. "-" .. selectedContact.realmName)
    else
      table.insert(parts, selectedContact.realmName)
    end
  elseif selectedContact.characterName and selectedContact.characterName ~= "" then
    local realm = selectedContact.realm or ""
    if realm ~= "" then
      table.insert(parts, selectedContact.characterName .. "-" .. realm)
    else
      table.insert(parts, selectedContact.characterName)
    end
  end

  if selectedContact.className and selectedContact.className ~= "" then
    table.insert(parts, selectedContact.className)
  end

  -- Show faction (inferred from race, or direct from BNet API)
  local factionName = selectedContact.factionName
  if factionName and factionName ~= "" then
    table.insert(parts, factionName)
  end

  local sep = "  " .. string.char(194, 183) .. "  "
  return table.concat(parts, sep), dotColor
end

ns.ConversationPaneStatusLine = StatusLine

return StatusLine
