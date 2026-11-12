local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The game's Who panels while our quiet /who is in flight. FriendsFrame pops
-- the Who window on WHO_LIST_UPDATE, and on WoW: Forever so does the Group
-- Finder's Who tab, so their event stays unregistered until we are done.
local WhoPanels = {}

local WHO_EVENT = "WHO_LIST_UPDATE"
local WHO_LISTENERS = { "FriendsFrame", "LFGWhoListFrame" }
local WHO_PANELS = { "WhoFrame", "LFGWhoListFrame" }

local function setWhoListeners(method)
  for _, name in ipairs(WHO_LISTENERS) do
    local frame = _G[name]
    if frame and frame[method] then
      frame[method](frame, WHO_EVENT)
    end
  end
end

-- IsVisible, not IsShown: a closed parent leaves its Who tab shown.
local function whoPanelVisible()
  for _, name in ipairs(WHO_PANELS) do
    local frame = _G[name]
    if frame and frame.IsVisible and frame:IsVisible() == true then
      return true
    end
  end
  return false
end

-- Quiets the panels and routes the answer to the UI. Returns the game's
-- previous WhoToUi flag for Release. Throws when C_FriendList is missing.
function WhoPanels.Claim()
  setWhoListeners("UnregisterEvent")
  local api = _G.C_FriendList
  local previous = false
  if api.GetWhoToUi then
    previous = api.GetWhoToUi() or false
  end
  api.SetWhoToUi(true)
  return previous
end

-- Gives the panels their event back. The WhoToUi flag stays on while a Who
-- panel is on screen, else returns to what it was before Claim.
function WhoPanels.Release(previous)
  setWhoListeners("RegisterEvent")
  local api = _G.C_FriendList
  if api and api.SetWhoToUi then
    api.SetWhoToUi(whoPanelVisible() or previous == true)
  end
end

ns.WhoPanels = WhoPanels
return WhoPanels
