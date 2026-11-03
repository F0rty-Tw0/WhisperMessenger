local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local ProfileCharacter = ns.ProfileCharacter or require("WhisperMessenger.Model.ProfileCharacter")
local ProfileLinks = ns.ProfileLinks or require("WhisperMessenger.Model.ProfileLinks")
local PopupUI = ns.ChatBubbleContextMenuManualCopyPopupUI or require("WhisperMessenger.UI.ChatBubble.ContextMenu.ManualCopy.PopupUI")

-- "Copy profile link" submenu: one entry per profile site of this game for
-- the contact's character. Picking one opens the copy popup with the URL.
local ProfileLinksMenuEntry = {}

local LINK_PROMPT = "Press Ctrl+C to copy the link."

local function buildLinks(item)
  if FlavorCompat.isForever then
    return {}
  end
  local game = {
    regionId = FlavorCompat.CurrentRegion(),
    projectId = FlavorCompat.projectId,
    seasonId = FlavorCompat.ActiveSeason(),
  }
  local character = ProfileCharacter.FromItem(item, ProfileCharacter.OwnRealm(), game)
  if character == nil then
    return {}
  end
  return ProfileLinks.Build(character, game)
end

-- Empty when no site applies (WoW: Forever, China, no known character).
-- Runs before the rest of our menu section, so it must never raise: a
-- missed secret value would otherwise take every entry with it.
function ProfileLinksMenuEntry.Links(item)
  local ok, links = pcall(buildLinks, item)
  return ok and links or {}
end

function ProfileLinksMenuEntry.Add(rootDescription, links)
  if #links == 0 then
    return
  end
  local submenu = rootDescription:CreateButton(Localization.Text("Copy profile link"))
  if submenu == nil or type(submenu.CreateButton) ~= "function" then
    return
  end
  for _, link in ipairs(links) do
    local url = link.url
    submenu:CreateButton(Localization.Text(link.label), function()
      PopupUI.ShowManualCopyDialog(url, { prompt = LINK_PROMPT })
    end)
  end
end

ns.ContactsListProfileLinksMenuEntry = ProfileLinksMenuEntry
return ProfileLinksMenuEntry
