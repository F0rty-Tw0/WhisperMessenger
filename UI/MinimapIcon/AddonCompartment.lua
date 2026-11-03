local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconClick = ns.ToggleIconIconClick or require("WhisperMessenger.UI.ToggleIcon.IconClick")
local IconTooltip = ns.MinimapIconTooltip or require("WhisperMessenger.UI.MinimapIcon.IconTooltip")
local UnreadSummary = ns.UnreadSummary or require("WhisperMessenger.UI.Shared.UnreadSummary")

-- The entry in Retail's addon compartment (the addon list button by the
-- minimap). Classic flavors and WoW: Forever have no compartment, so
-- Register does nothing there.
local AddonCompartment = {}

local TITLE = "Whisper Messenger"
local ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"
local ANCHOR = "ANCHOR_LEFT"

--- Adds the entry through AddonCompartmentFrame:RegisterAddon.
-- The compartment rebuilds its menu from the entry table each time it opens,
-- so setUnreadCount only rewrites `text`; no refresh call is needed.
-- @param options table — { onToggle?, onMarkAllRead?, getHideFromDefaultChat? }
-- @return table|nil — { setUnreadCount(total, whispers) }, nil with no compartment
function AddonCompartment.Register(options)
  options = options or {}
  local compartment = _G.AddonCompartmentFrame
  if type(compartment) ~= "table" or type(compartment.RegisterAddon) ~= "function" then
    return nil
  end

  local onClick = IconClick.Create(options)
  local unreadLine = ""
  local data = {
    text = TITLE,
    icon = ICON_TEXTURE,
    -- menuInputData.buttonName is the mouse button; the minimap icon's click
    -- rules (left toggles, shift-left marks all read) apply unchanged.
    func = function(_data, menuInputData)
      onClick(nil, menuInputData and menuInputData.buttonName)
    end,
    funcOnEnter = function(button)
      local includeReply = type(options.getHideFromDefaultChat) == "function" and options.getHideFromDefaultChat() == true
      IconTooltip.Show(button, ANCHOR, unreadLine, includeReply)
    end,
    funcOnLeave = IconTooltip.Hide,
  }
  compartment:RegisterAddon(data)

  -- total: the icon number (whispers plus addon page items); whispers: the
  -- whisper part, for the tooltip split.
  local function setUnreadCount(total, whispers)
    local count = tonumber(total) or 0
    data.text = count > 0 and (TITLE .. " (" .. count .. ")") or TITLE
    unreadLine = UnreadSummary.Format(UnreadSummary.Split(total, whispers))
  end

  return { setUnreadCount = setUnreadCount }
end

ns.MinimapIconAddonCompartment = AddonCompartment
return AddonCompartment
