local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local KeybindHints = ns.KeybindHints or require("WhisperMessenger.UI.Shared.KeybindHints")

-- The minimap-style tooltip: title, the unread line when there is one, then
-- the key and click hints. The minimap icon and the addon compartment entry
-- both show it.
local IconTooltip = {}

--- @param owner table — the frame the tooltip anchors to
-- @param anchor string — GameTooltip anchor, e.g. "ANCHOR_BOTTOM"
-- @param unreadLine string|nil — nil or "" leaves the line out
-- @param includeReply boolean — also name the reply key
function IconTooltip.Show(owner, anchor, unreadLine, includeReply)
  local tooltip = _G.GameTooltip
  if not (tooltip and tooltip.SetOwner) then
    return
  end
  tooltip:SetOwner(owner, anchor)
  tooltip:SetText("Whisper Messenger")
  if unreadLine ~= nil and unreadLine ~= "" then
    tooltip:AddLine(unreadLine)
  end
  KeybindHints.AddToTooltip(tooltip, includeReply)
  KeybindHints.AddClickHint(tooltip)
  tooltip:Show()
end

function IconTooltip.Hide()
  if _G.GameTooltip and _G.GameTooltip.Hide then
    _G.GameTooltip:Hide()
  end
end

ns.MinimapIconTooltip = IconTooltip
return IconTooltip
