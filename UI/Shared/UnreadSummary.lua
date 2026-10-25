local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The one place that words the icon number: whispers and the panel items
-- (addon pages) that the number also counts. Widget tooltip, minimap
-- tooltip, LDB text and LDB tooltip all call Format.
local UnreadSummary = {}

local PANEL_KEY = "%d in addon pages"

local function positive(value)
  local number = tonumber(value) or 0

  return number > 0 and number or 0
end

--- Splits the shown total into whispers and panel items.
-- @param total number|nil — the number on the icon
-- @param whispers number|nil — whispers inside it; nil means all of it
-- @return number whispers, number panelItems
function UnreadSummary.Split(total, whispers)
  local shown = positive(total)
  local unread = whispers == nil and shown or positive(whispers)

  return unread, math.max(0, shown - unread)
end

--- "2 unread", "2 unread, 1 in addon pages", "1 in addon pages", or "".
function UnreadSummary.Format(unread, panelCount)
  local whisperCount = positive(unread)
  local panelItems = positive(panelCount)
  local parts = {}
  if whisperCount > 0 then
    parts[#parts + 1] = whisperCount .. " " .. Localization.Text("unread")
  end
  if panelItems > 0 then
    parts[#parts + 1] = string.format(Localization.Text(PANEL_KEY), panelItems)
  end

  return table.concat(parts, ", ")
end

ns.UnreadSummary = UnreadSummary
return UnreadSummary
